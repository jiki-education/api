require "test_helper"

class Analytics::ExerciseHealth::CalculateMetricsTest < ActiveSupport::TestCase
  test "classifies sessions and computes funnel, effort, sentiment and chat metrics" do
    Prosopite.finish

    level = create(:level)
    video = create(:lesson, :video, level:)
    exercise = create(:lesson, :exercise, level:, title: "Fix the Wall")

    # Completed: 3 attempts over 30 minutes, rated.
    completer = create(:user)
    completer_ul = create(:user_lesson, user: completer, lesson: exercise,
      started_at: 2.days.ago, completed_at: 2.days.ago + 30.minutes,
      difficulty_rating: 4, fun_rating: 2)
    create_list(:exercise_submission, 3, context: completer_ul)

    # Abandoned: 2 attempts, inactive for 9 days, chatted with Ask Jiki.
    abandoner = create(:user)
    abandoner_ul = create(:user_lesson, user: abandoner, lesson: exercise, started_at: 10.days.ago)
    create_list(:exercise_submission, 2, context: abandoner_ul).each { |sub| sub.update!(created_at: 9.days.ago) }
    create(:assistant_conversation, user: abandoner, context: exercise)

    # Bounced: started 10 days ago, never submitted.
    bouncer = create(:user)
    create(:user_lesson, user: bouncer, lesson: exercise, started_at: 10.days.ago)

    # In progress: started yesterday, excluded from outcome denominators.
    create(:user_lesson, lesson: exercise, started_at: 1.day.ago)

    # Reach→start: completer, abandoner and bouncer all completed the video
    # 8+ days ago and started the exercise; one extra user completed the
    # video but never started the exercise; one completed it too recently
    # to be counted as having dropped off.
    [completer, abandoner, bouncer].each do |user|
      create(:user_lesson, user:, lesson: video, started_at: 9.days.ago, completed_at: 8.days.ago)
    end
    create(:user_lesson, lesson: video, started_at: 9.days.ago, completed_at: 8.days.ago)
    create(:user_lesson, lesson: video, started_at: 2.days.ago, completed_at: 1.day.ago)

    Prosopite.scan
    metrics = Analytics::ExerciseHealth::CalculateMetrics.()

    assert_equal 1, metrics.size
    m = metrics.first

    assert_equal exercise.id, m[:lesson_id]
    assert_equal exercise.slug, m[:slug]
    assert_equal "Fix the Wall", m[:title]

    assert_equal 4, m[:num_starts]
    assert_equal 1, m[:num_in_progress]
    assert_equal 3, m[:num_classifiable]
    assert_equal 1, m[:num_completed]
    assert_equal 1, m[:num_bounced]
    assert_equal 1, m[:num_abandoned]
    assert_in_delta 33.3, m[:completion_pct], 0.1
    assert_in_delta 33.3, m[:bounce_pct], 0.1
    assert_in_delta 33.3, m[:abandon_pct], 0.1

    assert_equal 3, m[:completer_median_attempts]
    assert_equal 3, m[:completer_p90_attempts]
    assert_equal 2, m[:abandoner_median_attempts]
    assert_in_delta 0.67, m[:struggle_ratio], 0.01
    assert_in_delta 30.0, m[:median_minutes_to_complete], 0.1

    assert_in_delta 4.0, m[:avg_difficulty], 0.01
    assert_in_delta 2.0, m[:avg_fun], 0.01

    # Engaged (>1 attempt): completer and abandoner. Only the abandoner chatted.
    assert_equal 2, m[:num_engaged]
    assert_in_delta 50.0, m[:ask_jiki_pct], 0.01

    # 4 users completed the video 7+ days ago; 3 of them started the exercise.
    assert_in_delta 75.0, m[:reach_start_pct], 0.01

    assert m[:low_sample]
    assert_nil m[:health_score]
  end

  test "computes health score with capped penalties once sample size is reached" do
    Prosopite.finish

    exercise = create(:lesson, :exercise)
    create_list(:user_lesson, 24, :completed, lesson: exercise, started_at: 2.days.ago)
    create_list(:user_lesson, 6, lesson: exercise, started_at: 10.days.ago).each do |ul|
      create(:exercise_submission, context: ul).update!(created_at: 9.days.ago)
    end

    Prosopite.scan
    m = Analytics::ExerciseHealth::CalculateMetrics.().first

    assert_equal 30, m[:num_classifiable]
    refute m[:low_sample]
    # 20% engaged abandonment maxes out the (heaviest) abandonment penalty
    # of 40. No other penalties apply.
    assert_in_delta 20.0, m[:abandon_pct], 0.01
    assert_equal 60, m[:health_score]
  end

  test "orders exercises by course position and only includes exercise lessons" do
    Prosopite.finish

    course = create(:course)
    level2 = create(:level, course:, position: 2)
    level1 = create(:level, course:, position: 1)
    late = create(:lesson, :exercise, level: level2)
    create(:lesson, :video, level: level1)
    early = create(:lesson, :exercise, level: level1)

    Prosopite.scan
    metrics = Analytics::ExerciseHealth::CalculateMetrics.()

    assert_equal([early.id, late.id], metrics.map { |m| m[:lesson_id] })
  end

  test "handles an exercise with no sessions and no previous lesson" do
    Prosopite.finish
    exercise = create(:lesson, :exercise)

    Prosopite.scan
    m = Analytics::ExerciseHealth::CalculateMetrics.().first

    assert_equal exercise.id, m[:lesson_id]
    assert_equal 0, m[:num_starts]
    assert_nil m[:completion_pct]
    assert_nil m[:reach_start_pct]
    assert_nil m[:struggle_ratio]
    assert_nil m[:health_score]
    assert m[:low_sample]
  end
end
