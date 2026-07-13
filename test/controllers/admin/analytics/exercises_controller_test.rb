require "test_helper"

class Admin::Analytics::ExercisesControllerTest < ApplicationControllerTest
  setup do
    @admin = create(:user, :admin)
    sign_in_user(@admin)
  end

  guard_admin! :admin_analytics_exercises_path, method: :get

  test "GET index returns insights and per-exercise metrics" do
    metrics = [{ lesson_id: 1, slug: "fix-wall", title: "Fix the Wall" }]
    insights = [{ type: :difficulty_wall, severity: :high, lesson_id: 1, slug: "fix-wall",
                  title: "Fix the Wall", message: "Learners give up here.", value: 13.2 }]

    Analytics::ExerciseHealth::CalculateMetrics.expects(:call).returns(metrics)
    Analytics::ExerciseHealth::GenerateInsights.expects(:call).with(metrics).returns(insights)

    get admin_analytics_exercises_path, as: :json

    assert_response :success
    assert_json_response({
      insights: SerializeAdminExerciseHealthInsights.(insights),
      exercises: SerializeAdminExerciseHealthMetrics.(metrics)
    })
  end
end
