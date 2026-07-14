class SerializeAdminExerciseHealthMetrics
  include Mandate

  initialize_with :metrics

  def call
    metrics.map { |metric| serialize(metric) }
  end

  private
  def serialize(metric)
    {
      lesson_id: metric[:lesson_id],
      slug: metric[:slug],
      title: metric[:title],
      health_score: metric[:health_score],
      low_sample: metric[:low_sample],
      num_starts: metric[:num_starts],
      num_in_progress: metric[:num_in_progress],
      num_completed: metric[:num_completed],
      num_bounced: metric[:num_bounced],
      num_abandoned: metric[:num_abandoned],
      completion_pct: round(metric[:completion_pct], 1),
      bounce_pct: round(metric[:bounce_pct], 1),
      abandon_pct: round(metric[:abandon_pct], 1),
      reach_start_pct: round(metric[:reach_start_pct], 1),
      completer_median_attempts: metric[:completer_median_attempts],
      completer_p90_attempts: metric[:completer_p90_attempts],
      abandoner_median_attempts: metric[:abandoner_median_attempts],
      struggle_ratio: round(metric[:struggle_ratio], 2),
      median_minutes_to_complete: round(metric[:median_minutes_to_complete], 1),
      avg_difficulty: round(metric[:avg_difficulty], 2),
      avg_fun: round(metric[:avg_fun], 2),
      num_engaged: metric[:num_engaged],
      ask_jiki_pct: round(metric[:ask_jiki_pct], 1)
    }
  end

  def round(value, precision) = value&.round(precision)
end
