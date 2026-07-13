require "test_helper"

class Analytics::ExerciseHealth::GenerateInsightsTest < ActiveSupport::TestCase
  def metric(overrides = {})
    {
      lesson_id: 1,
      slug: "fix-wall",
      title: "Fix the Wall",
      abandon_pct: 0.0,
      bounce_pct: 0.0,
      reach_start_pct: 100.0,
      avg_fun: 3.7,
      ask_jiki_pct: 50.0,
      abandoner_median_attempts: 8,
      low_sample: false
    }.merge(overrides)
  end

  test "returns no insights for healthy metrics" do
    assert_empty Analytics::ExerciseHealth::GenerateInsights.([metric])
  end

  test "skips low-sample exercises entirely" do
    metrics = [metric(abandon_pct: 50.0, bounce_pct: 50.0, avg_fun: 1.0, low_sample: true)]

    assert_empty Analytics::ExerciseHealth::GenerateInsights.(metrics)
  end

  test "flags a difficulty wall with severity based on threshold" do
    insights = Analytics::ExerciseHealth::GenerateInsights.([metric(abandon_pct: 9.0)])

    assert_equal 1, insights.size
    insight = insights.first
    assert_equal :difficulty_wall, insight[:type]
    assert_equal :medium, insight[:severity]
    assert_equal 1, insight[:lesson_id]
    assert_equal "fix-wall", insight[:slug]
    assert_equal "Fix the Wall", insight[:title]
    assert_equal 9.0, insight[:value]
    assert_includes insight[:message], "9.0% of learners attempt this exercise but give up"
    assert_includes insight[:message], "median 8 attempts"

    insights = Analytics::ExerciseHealth::GenerateInsights.([metric(abandon_pct: 13.0)])
    assert_equal :high, insights.first[:severity]
  end

  test "flags bounce" do
    insights = Analytics::ExerciseHealth::GenerateInsights.([metric(bounce_pct: 16.0)])

    assert_equal([:bounce], insights.map { |i| i[:type] })
    assert_equal :medium, insights.first[:severity]

    insights = Analytics::ExerciseHealth::GenerateInsights.([metric(bounce_pct: 35.0)])
    assert_equal :high, insights.first[:severity]
  end

  test "flags pre-start dropoff based on reach_start_pct" do
    insights = Analytics::ExerciseHealth::GenerateInsights.([metric(reach_start_pct: 80.0)])

    assert_equal([:pre_start_dropoff], insights.map { |i| i[:type] })
    assert_equal :medium, insights.first[:severity]
    assert_equal 20.0, insights.first[:value]
    assert_includes insights.first[:message], "20.0% of learners who completed the previous lesson never start this one"

    insights = Analytics::ExerciseHealth::GenerateInsights.([metric(reach_start_pct: 60.0)])
    assert_equal :high, insights.first[:severity]
  end

  test "flags fun crash" do
    insights = Analytics::ExerciseHealth::GenerateInsights.([metric(avg_fun: 3.2)])

    assert_equal([:fun_crash], insights.map { |i| i[:type] })
    assert_equal :medium, insights.first[:severity]
    assert_equal 3.2, insights.first[:value]

    insights = Analytics::ExerciseHealth::GenerateInsights.([metric(avg_fun: 2.9)])
    assert_equal :high, insights.first[:severity]
  end

  test "flags Ask Jiki underuse when abandonment is elevated and chat usage is low" do
    insights = Analytics::ExerciseHealth::GenerateInsights.([metric(abandon_pct: 7.0, ask_jiki_pct: 5.0)])

    assert_equal([:ask_jiki_underuse], insights.map { |i| i[:type] })
    assert_includes insights.first[:message], "only 5.0% of those who hit friction use Ask Jiki"

    # High chat usage means no underuse insight even with elevated abandonment.
    assert_empty Analytics::ExerciseHealth::GenerateInsights.([metric(abandon_pct: 7.0, ask_jiki_pct: 40.0)])
  end

  test "handles nil metrics without raising" do
    metrics = [metric(abandon_pct: nil, bounce_pct: nil, reach_start_pct: nil, avg_fun: nil, ask_jiki_pct: nil)]

    assert_empty Analytics::ExerciseHealth::GenerateInsights.(metrics)
  end

  test "sorts high severity first, then by magnitude, and caps the list" do
    metrics = (1..10).map do |i|
      metric(
        lesson_id: i,
        slug: "lesson-#{i}",
        abandon_pct: i.odd? ? 8.0 + (i * 0.3) : 13.0 + i # odd => medium, even => high
      )
    end

    insights = Analytics::ExerciseHealth::GenerateInsights.(metrics)

    assert_equal Analytics::ExerciseHealth::GenerateInsights::MAX_INSIGHTS, insights.size
    # All high-severity insights (even lesson_ids) come first, worst first.
    assert_equal([10, 8, 6, 4, 2], insights.first(5).map { |i| i[:lesson_id] })
    assert(insights.first(5).all? { |i| i[:severity] == :high })
    # Remaining slots filled by the worst medium-severity insights.
    assert_equal([9, 7, 5], insights.last(3).map { |i| i[:lesson_id] })
  end
end
