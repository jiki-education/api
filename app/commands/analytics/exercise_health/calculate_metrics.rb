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
#
# All per-session work (classification, percentiles, chat lookups) happens in
# SQL: the database only ever returns one aggregate row per lesson, so memory
# use doesn't grow with the number of users.
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
    stats = session_stats[lesson_id] || EMPTY_SESSION_STATS
    classifiable = stats["num_completed"] + stats["num_bounced"] + stats["num_abandoned"]
    completer_median = stats["completer_median_attempts"]
    abandoner_median = stats["abandoner_median_attempts"]

    {
      lesson_id:,
      slug:,
      title:,
      num_starts: stats["num_starts"],
      num_in_progress: stats["num_in_progress"],
      num_classifiable: classifiable,
      num_completed: stats["num_completed"],
      num_bounced: stats["num_bounced"],
      num_abandoned: stats["num_abandoned"],
      completion_pct: pct(stats["num_completed"], classifiable),
      bounce_pct: pct(stats["num_bounced"], classifiable),
      abandon_pct: pct(stats["num_abandoned"], classifiable),
      completer_median_attempts: completer_median,
      completer_p90_attempts: stats["completer_p90_attempts"],
      abandoner_median_attempts: abandoner_median,
      struggle_ratio: struggle_ratio(abandoner_median, completer_median),
      median_minutes_to_complete: stats["median_minutes_to_complete"]&.to_f,
      avg_difficulty: stats["avg_difficulty"]&.to_f,
      avg_fun: stats["avg_fun"]&.to_f,
      num_engaged: stats["num_engaged"],
      ask_jiki_pct: pct(stats["num_engaged_chatted"], stats["num_engaged"]),
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
    stats = reach_stats[lesson_id]
    return nil unless stats

    pct(stats["num_starters"], stats["num_reachers"])
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
  def exercise_lesson_ids = exercise_lessons.map(&:first)

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

  EMPTY_SESSION_STATS = {
    "num_starts" => 0,
    "num_in_progress" => 0,
    "num_completed" => 0,
    "num_bounced" => 0,
    "num_abandoned" => 0,
    "num_engaged" => 0,
    "num_engaged_chatted" => 0
  }.freeze

  # One aggregate row per lesson. Sessions are classified in the CTE
  # (mirroring the definitions above), then rolled up with FILTERed
  # aggregates and discrete percentiles.
  memoize
  def session_stats
    return {} if exercise_lesson_ids.empty?

    sql = <<~SQL.squish
      WITH sessions AS (
        SELECT ul.lesson_id,
               ul.difficulty_rating,
               ul.fun_rating,
               COUNT(es.id) AS num_attempts,
               CASE
                 WHEN ul.completed_at IS NOT NULL THEN 'completed'
                 WHEN GREATEST(MAX(es.created_at), ul.started_at) IS NULL
                   OR GREATEST(MAX(es.created_at), ul.started_at) >= :cutoff THEN 'in_progress'
                 WHEN COUNT(es.id) = 0 THEN 'bounced'
                 ELSE 'abandoned'
               END AS status,
               EXTRACT(EPOCH FROM (ul.completed_at - ul.started_at)) / 60.0 AS minutes,
               EXISTS (
                 SELECT 1 FROM assistant_conversations ac
                 WHERE ac.user_id = ul.user_id
                   AND ac.context_type = 'Lesson'
                   AND ac.context_id = ul.lesson_id
               ) AS chatted
        FROM user_lessons ul
        LEFT JOIN exercise_submissions es
          ON es.context_type = 'UserLesson' AND es.context_id = ul.id
        WHERE ul.lesson_id IN (:lesson_ids)
        GROUP BY ul.id
      )
      SELECT lesson_id,
             COUNT(*) AS num_starts,
             COUNT(*) FILTER (WHERE status = 'in_progress') AS num_in_progress,
             COUNT(*) FILTER (WHERE status = 'completed') AS num_completed,
             COUNT(*) FILTER (WHERE status = 'bounced') AS num_bounced,
             COUNT(*) FILTER (WHERE status = 'abandoned') AS num_abandoned,
             PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY num_attempts)
               FILTER (WHERE status = 'completed') AS completer_median_attempts,
             PERCENTILE_DISC(0.9) WITHIN GROUP (ORDER BY num_attempts)
               FILTER (WHERE status = 'completed') AS completer_p90_attempts,
             PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY num_attempts)
               FILTER (WHERE status = 'abandoned') AS abandoner_median_attempts,
             PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY minutes)
               FILTER (WHERE status = 'completed' AND minutes IS NOT NULL) AS median_minutes_to_complete,
             AVG(difficulty_rating) AS avg_difficulty,
             AVG(fun_rating) AS avg_fun,
             COUNT(*) FILTER (WHERE num_attempts > 1) AS num_engaged,
             COUNT(*) FILTER (WHERE num_attempts > 1 AND chatted) AS num_engaged_chatted
      FROM sessions
      GROUP BY lesson_id
    SQL

    select_rows(sql, cutoff:, lesson_ids: exercise_lesson_ids)
  end

  # One aggregate row per lesson: how many users completed its predecessor
  # at least INACTIVITY_CUTOFF ago, and how many of those started it.
  memoize
  def reach_stats
    pairs = exercise_lesson_ids.filter_map do |lesson_id|
      prev_id = previous_lesson_ids[lesson_id]
      "(#{prev_id.to_i}, #{lesson_id.to_i})" if prev_id
    end
    return {} if pairs.empty?

    sql = <<~SQL.squish
      SELECT pairs.target_id AS lesson_id,
             COUNT(prev.id) AS num_reachers,
             COUNT(started.id) AS num_starters
      FROM (VALUES #{pairs.join(', ')}) AS pairs(prev_id, target_id)
      JOIN user_lessons prev
        ON prev.lesson_id = pairs.prev_id AND prev.completed_at <= :cutoff
      LEFT JOIN user_lessons started
        ON started.lesson_id = pairs.target_id AND started.user_id = prev.user_id
      GROUP BY pairs.target_id
    SQL

    select_rows(sql, cutoff:)
  end

  def select_rows(sql, binds)
    ApplicationRecord.connection.
      select_all(ApplicationRecord.sanitize_sql_array([sql, binds])).
      to_a.
      index_by { |row| row["lesson_id"] }
  end

  def pct(numerator, denominator)
    return nil if denominator.zero?

    numerator * 100.0 / denominator
  end
end
