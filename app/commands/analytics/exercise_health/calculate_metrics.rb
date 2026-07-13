# Computes per-exercise health metrics for the admin analytics dashboard.
#
# Each exercise lesson gets one row (in course order) covering funnel health
# (reach→start, bounce, engaged abandonment, completion), effort (attempt
# percentiles, struggle ratio, time to complete), sentiment (difficulty/fun
# ratings) and Ask Jiki usage, plus a composite health score.
#
# Sessions inactive for less than INACTIVITY_CUTOFF are "in progress" and are
# excluded from outcome denominators - counting them as abandoned inflates
# drop-off for recently-started sessions.
class Analytics::ExerciseHealth::CalculateMetrics
  include Mandate

  INACTIVITY_CUTOFF = 7.days
  MIN_SAMPLE_SIZE = 30

  def call
    exercise_lessons.map { |lesson_id, slug, title, _, _| metrics_for(lesson_id, slug, title) }
  end

  private
  memoize
  def cutoff = INACTIVITY_CUTOFF.ago

  def metrics_for(lesson_id, slug, title)
    sessions = sessions_by_lesson[lesson_id] || []
    completed = sessions.select { |s| s[:status] == :completed }
    bounced = sessions.select { |s| s[:status] == :bounced }
    abandoned = sessions.select { |s| s[:status] == :abandoned }
    classifiable = completed.size + bounced.size + abandoned.size

    completer_median = median(completed.map { |s| s[:num_attempts] })
    abandoner_median = median(abandoned.map { |s| s[:num_attempts] })
    engaged = sessions.select { |s| s[:num_attempts] > 1 }
    chatted = engaged.count { |s| chats.include?([s[:user_id], lesson_id]) }

    {
      lesson_id:,
      slug:,
      title:,
      num_starts: sessions.size,
      num_in_progress: sessions.size - classifiable,
      num_classifiable: classifiable,
      num_completed: completed.size,
      num_bounced: bounced.size,
      num_abandoned: abandoned.size,
      completion_pct: pct(completed.size, classifiable),
      bounce_pct: pct(bounced.size, classifiable),
      abandon_pct: pct(abandoned.size, classifiable),
      completer_median_attempts: completer_median,
      completer_p90_attempts: p90(completed.map { |s| s[:num_attempts] }),
      abandoner_median_attempts: abandoner_median,
      struggle_ratio: struggle_ratio(abandoner_median, completer_median),
      median_minutes_to_complete: median(completed.filter_map { |s| s[:minutes] }),
      avg_difficulty: average(sessions.filter_map { |s| s[:difficulty_rating] }),
      avg_fun: average(sessions.filter_map { |s| s[:fun_rating] }),
      num_engaged: engaged.size,
      ask_jiki_pct: pct(chatted, engaged.size),
      reach_start_pct: reach_start_pct(lesson_id),
      low_sample: classifiable < MIN_SAMPLE_SIZE
    }.tap do |metrics|
      metrics[:health_score] = health_score(metrics)
    end
  end

  # Of the users who completed the previous lesson in course order at least
  # INACTIVITY_CUTOFF ago, what percentage went on to start this one?
  # Low values flag lessons that put people off before they even open them.
  def reach_start_pct(lesson_id)
    prev_id = previous_lesson_ids[lesson_id]
    return nil unless prev_id

    reachers = previous_lesson_completers[prev_id]
    return nil if reachers.blank?

    starters = sessions_by_lesson[lesson_id]&.map { |s| s[:user_id] }&.to_set || Set.new
    pct(reachers.count { |user_id| starters.include?(user_id) }, reachers.size)
  end

  def struggle_ratio(abandoner_median, completer_median)
    return nil if abandoner_median.nil? || completer_median.nil? || completer_median.zero?

    abandoner_median.to_f / completer_median
  end

  # Explainable penalty model: start at 100 and subtract capped, weighted
  # penalties per problem dimension. Engaged abandonment (tried, then quit)
  # is weighted heaviest as it is the strongest signal of a content problem.
  def health_score(metrics)
    return nil if metrics[:low_sample]

    penalty = 0.0
    penalty += [metrics[:abandon_pct] / 15.0, 1.0].min * 40.0 if metrics[:abandon_pct]
    penalty += [metrics[:bounce_pct] / 30.0, 1.0].min * 15.0 if metrics[:bounce_pct]
    penalty += [(100.0 - metrics[:reach_start_pct]) / 30.0, 1.0].min * 15.0 if metrics[:reach_start_pct]
    penalty += [3.5 - metrics[:avg_fun], 1.0].min * 15.0 if metrics[:avg_fun] && metrics[:avg_fun] < 3.5
    penalty += [metrics[:struggle_ratio] - 1.0, 1.0].min * 15.0 if metrics[:struggle_ratio] && metrics[:struggle_ratio] > 1.0

    (100.0 - penalty).round.clamp(0, 100)
  end

  # All lessons (all types) in course order, used both to select exercise
  # lessons and to determine each lesson's predecessor for reach→start.
  memoize
  def ordered_lessons
    Lesson.joins(:level).
      reorder("levels.course_id, levels.position, lessons.position").
      pluck("lessons.id", :slug, :title, :type, "levels.course_id")
  end

  memoize
  def exercise_lessons = ordered_lessons.select { |_, _, _, type, _| type == "exercise" }

  memoize
  def previous_lesson_ids
    {}.tap do |prev_ids|
      ordered_lessons.group_by { |_, _, _, _, course_id| course_id }.each_value do |course_lessons|
        course_lessons.each_cons(2) do |(prev_id, *), (id, *)|
          prev_ids[id] = prev_id
        end
      end
    end
  end

  memoize
  def sessions_by_lesson
    rows = UserLesson.where(lesson_id: exercise_lessons.map(&:first)).
      left_joins(:exercise_submissions).
      group("user_lessons.id").
      pluck(
        "user_lessons.id", :lesson_id, :user_id, :started_at, :completed_at,
        :difficulty_rating, :fun_rating,
        Arel.sql("COUNT(exercise_submissions.id)"),
        Arel.sql("MAX(exercise_submissions.created_at)")
      )

    sessions = rows.map do |_, lesson_id, user_id, started_at, completed_at, difficulty_rating, fun_rating, num_attempts, last_attempt_at| # rubocop:disable Layout/LineLength
      {
        lesson_id:,
        user_id:,
        difficulty_rating:,
        fun_rating:,
        num_attempts:,
        status: status_for(started_at, completed_at, num_attempts, last_attempt_at),
        minutes: completed_at && started_at ? (completed_at - started_at) / 60.0 : nil
      }
    end
    sessions.group_by { |s| s[:lesson_id] }
  end

  def status_for(started_at, completed_at, num_attempts, last_attempt_at)
    return :completed if completed_at

    last_activity = [last_attempt_at, started_at].compact.max
    return :in_progress if last_activity.nil? || last_activity >= cutoff

    num_attempts.zero? ? :bounced : :abandoned
  end

  memoize
  def previous_lesson_completers
    UserLesson.where(lesson_id: previous_lesson_ids.values_at(*exercise_lessons.map(&:first)).compact).
      where(completed_at: ..cutoff).
      pluck(:lesson_id, :user_id).
      group_by(&:first).
      transform_values { |pairs| pairs.map(&:last) }
  end

  memoize
  def chats
    AssistantConversation.where(
      context_type: "Lesson",
      context_id: exercise_lessons.map(&:first)
    ).pluck(:user_id, :context_id).to_set
  end

  def pct(numerator, denominator)
    return nil if denominator.zero?

    numerator * 100.0 / denominator
  end

  def average(values)
    return nil if values.empty?

    values.sum.to_f / values.size
  end

  def median(values)
    return nil if values.empty?

    values.sort[(values.length - 1) / 2]
  end

  def p90(values)
    return nil if values.empty?

    values.sort[((values.length - 1) * 0.9).round]
  end
end
