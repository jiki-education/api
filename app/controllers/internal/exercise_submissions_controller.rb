class Internal::ExerciseSubmissionsController < Internal::BaseController
  before_action :use_submission!

  def update
    ExerciseSubmission::UpdateProgressionScores.(
      @submission,
      progression_scores_params[:progression_scores]
    )

    render json: {}, status: :ok
  end

  private
  def progression_scores_params
    params.require(:submission).permit(progression_scores: {})
  end

  # Looks up a submission by uuid, scoped to the current user (a submission
  # delegates #user to its polymorphic context), 404ing otherwise.
  def use_submission!
    @submission = ExerciseSubmission.find_by(uuid: params[:uuid])
    render_404(:exercise_submission_not_found) unless @submission&.user == current_user
  end
end
