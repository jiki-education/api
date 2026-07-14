# Turns per-exercise health metrics (from CalculateMetrics) into a ranked
# list of actionable insights for the admin dashboard.
#
# Each rule flags a distinct failure mode with a distinct remedy:
# - difficulty_wall:    users try hard, then give up → fix difficulty/hints
# - bounce:             users open it but never submit → fix presentation/intro
# - pre_start_dropoff:  users never open it at all → fix title/positioning
# - fun_crash:          users complete it but hate it → fix the grind
# - ask_jiki_underuse:  strugglers aren't reaching for help → surface Ask Jiki
#
# Low-sample exercises are skipped: with a handful of starts every rate
# metric is noise and the tail of the course would dominate every list.
class Analytics::ExerciseHealth::GenerateInsights
  include Mandate

  initialize_with :metrics

  MAX_INSIGHTS = 8

  DIFFICULTY_WALL_THRESHOLD = 8.0 # % of classifiable sessions engaged-then-abandoned
  DIFFICULTY_WALL_HIGH_THRESHOLD = 12.0
  BOUNCE_THRESHOLD = 15.0 # % of classifiable sessions with zero attempts
  BOUNCE_HIGH_THRESHOLD = 30.0
  PRE_START_DROPOFF_THRESHOLD = 15.0 # % of previous-lesson completers never starting
  PRE_START_DROPOFF_HIGH_THRESHOLD = 30.0
  FUN_CRASH_THRESHOLD = 3.3 # avg fun rating
  FUN_CRASH_HIGH_THRESHOLD = 3.0
  ASK_JIKI_ABANDON_THRESHOLD = 6.0 # abandon % above which chat usage matters
  ASK_JIKI_USAGE_THRESHOLD = 15.0 # % of engaged users chatting

  def call
    insights.
      sort_by { |insight| [insight[:severity] == :high ? 0 : 1, -insight.delete(:sort_value)] }.
      first(MAX_INSIGHTS)
  end

  private
  memoize
  def insights
    reliable_metrics.flat_map do |metric|
      [
        difficulty_wall_insight(metric),
        bounce_insight(metric),
        pre_start_dropoff_insight(metric),
        fun_crash_insight(metric),
        ask_jiki_underuse_insight(metric)
      ].compact
    end
  end

  memoize
  def reliable_metrics = metrics.reject { |metric| metric[:low_sample] }

  def difficulty_wall_insight(metric)
    return nil unless metric[:abandon_pct] && metric[:abandon_pct] >= DIFFICULTY_WALL_THRESHOLD

    attempts = metric[:abandoner_median_attempts]
    build_insight(
      metric, :difficulty_wall, metric[:abandon_pct],
      severity: metric[:abandon_pct] >= DIFFICULTY_WALL_HIGH_THRESHOLD ? :high : :medium,
      message: "#{metric[:abandon_pct].round(1)}% of learners attempt this exercise but give up " \
               "(median #{attempts} attempt#{'s' unless attempts == 1} before quitting) - likely a difficulty wall."
    )
  end

  def bounce_insight(metric)
    return nil unless metric[:bounce_pct] && metric[:bounce_pct] >= BOUNCE_THRESHOLD

    build_insight(
      metric, :bounce, metric[:bounce_pct],
      severity: metric[:bounce_pct] >= BOUNCE_HIGH_THRESHOLD ? :high : :medium,
      message: "#{metric[:bounce_pct].round(1)}% of learners open this exercise but never submit - " \
               "the intro or first step may be off-putting."
    )
  end

  def pre_start_dropoff_insight(metric)
    return nil unless metric[:reach_start_pct]

    dropoff = 100.0 - metric[:reach_start_pct]
    return nil unless dropoff >= PRE_START_DROPOFF_THRESHOLD

    build_insight(
      metric, :pre_start_dropoff, dropoff,
      severity: dropoff >= PRE_START_DROPOFF_HIGH_THRESHOLD ? :high : :medium,
      message: "#{dropoff.round(1)}% of learners who completed the previous lesson never start this one - " \
               "it may look too boring or too scary."
    )
  end

  def fun_crash_insight(metric)
    return nil unless metric[:avg_fun] && metric[:avg_fun] <= FUN_CRASH_THRESHOLD

    build_insight(
      metric, :fun_crash, metric[:avg_fun],
      sort_value: 5.0 - metric[:avg_fun],
      severity: metric[:avg_fun] <= FUN_CRASH_HIGH_THRESHOLD ? :high : :medium,
      message: "Average fun rating is only #{metric[:avg_fun].round(2)} - " \
               "learners are finishing it but not enjoying it."
    )
  end

  def ask_jiki_underuse_insight(metric)
    return nil unless metric[:abandon_pct] && metric[:abandon_pct] >= ASK_JIKI_ABANDON_THRESHOLD
    return nil unless metric[:ask_jiki_pct] && metric[:ask_jiki_pct] < ASK_JIKI_USAGE_THRESHOLD

    build_insight(
      metric, :ask_jiki_underuse, metric[:abandon_pct] - metric[:ask_jiki_pct],
      severity: :medium,
      message: "Learners are abandoning this exercise (#{metric[:abandon_pct].round(1)}%) but only " \
               "#{metric[:ask_jiki_pct].round(1)}% of those who hit friction use Ask Jiki - consider surfacing it here."
    )
  end

  # sort_value ranks insights within a severity band (higher = worse). It
  # defaults to the displayed value but is overridden where a lower displayed
  # value means a worse problem (e.g. fun ratings).
  def build_insight(metric, type, value, severity:, message:, sort_value: value)
    {
      type:,
      severity:,
      lesson_id: metric[:lesson_id],
      slug: metric[:slug],
      title: metric[:title],
      message:,
      value: value.round(2),
      sort_value:
    }
  end
end
