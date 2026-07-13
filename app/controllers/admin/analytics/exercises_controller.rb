class Admin::Analytics::ExercisesController < Admin::BaseController
  def index
    metrics = Analytics::ExerciseHealth::CalculateMetrics.()
    insights = Analytics::ExerciseHealth::GenerateInsights.(metrics)

    render json: {
      insights: SerializeAdminExerciseHealthInsights.(insights),
      exercises: SerializeAdminExerciseHealthMetrics.(metrics)
    }
  end
end
