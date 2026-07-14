require "test_helper"

class SerializeAdminExerciseHealthInsightsTest < ActiveSupport::TestCase
  test "serializes insights without internal keys" do
    insights = [{
      type: :difficulty_wall,
      severity: :high,
      lesson_id: 5,
      slug: "fix-wall",
      title: "Fix the Wall",
      message: "Learners give up here.",
      value: 13.2
    }]

    expected = [{
      type: :difficulty_wall,
      severity: :high,
      lesson_id: 5,
      slug: "fix-wall",
      title: "Fix the Wall",
      message: "Learners give up here.",
      value: 13.2
    }]

    assert_equal expected, SerializeAdminExerciseHealthInsights.(insights)
  end
end
