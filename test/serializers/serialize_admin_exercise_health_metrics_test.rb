require "test_helper"

class SerializeAdminExerciseHealthMetricsTest < ActiveSupport::TestCase
  test "serializes metrics with rounding" do
    metrics = [{
      lesson_id: 5,
      slug: "fix-wall",
      title: "Fix the Wall",
      health_score: 72,
      low_sample: false,
      num_starts: 100,
      num_in_progress: 10,
      num_classifiable: 90,
      num_completed: 80,
      num_bounced: 4,
      num_abandoned: 6,
      completion_pct: 88.888,
      bounce_pct: 4.444,
      abandon_pct: 6.666,
      reach_start_pct: 91.234,
      completer_median_attempts: 6,
      completer_p90_attempts: 43,
      abandoner_median_attempts: 8,
      struggle_ratio: 1.3333,
      median_minutes_to_complete: 6.4444,
      avg_difficulty: 2.7111,
      avg_fun: 3.5555,
      num_engaged: 70,
      ask_jiki_pct: 11.111
    }]

    expected = [{
      lesson_id: 5,
      slug: "fix-wall",
      title: "Fix the Wall",
      health_score: 72,
      low_sample: false,
      num_starts: 100,
      num_in_progress: 10,
      num_completed: 80,
      num_bounced: 4,
      num_abandoned: 6,
      completion_pct: 88.9,
      bounce_pct: 4.4,
      abandon_pct: 6.7,
      reach_start_pct: 91.2,
      completer_median_attempts: 6,
      completer_p90_attempts: 43,
      abandoner_median_attempts: 8,
      struggle_ratio: 1.33,
      median_minutes_to_complete: 6.4,
      avg_difficulty: 2.71,
      avg_fun: 3.56,
      num_engaged: 70,
      ask_jiki_pct: 11.1
    }]

    assert_equal expected, SerializeAdminExerciseHealthMetrics.(metrics)
  end

  test "passes through nil values" do
    metrics = [{
      lesson_id: 5,
      slug: "new-exercise",
      title: "New Exercise",
      health_score: nil,
      low_sample: true,
      num_starts: 0,
      num_in_progress: 0,
      num_classifiable: 0,
      num_completed: 0,
      num_bounced: 0,
      num_abandoned: 0,
      completion_pct: nil,
      bounce_pct: nil,
      abandon_pct: nil,
      reach_start_pct: nil,
      completer_median_attempts: nil,
      completer_p90_attempts: nil,
      abandoner_median_attempts: nil,
      struggle_ratio: nil,
      median_minutes_to_complete: nil,
      avg_difficulty: nil,
      avg_fun: nil,
      num_engaged: 0,
      ask_jiki_pct: nil
    }]

    serialized = SerializeAdminExerciseHealthMetrics.(metrics).first

    assert_nil serialized[:health_score]
    assert_nil serialized[:completion_pct]
    assert_nil serialized[:struggle_ratio]
    assert serialized[:low_sample]
  end
end
