# LEGACY: pre-rename projects API, identical to the old public surface.
# Kept so admin front ends deployed before the projects -> challenges rename
# keep working. Delete once the admin front end has been deployed.
class Admin::ProjectsController < Admin::ChallengesController
  def create
    challenge = Challenge::Create.(challenge_params)
    render json: {
      project: SerializeAdminProject.(challenge)
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_422(:validation_error, errors: e.record.errors.as_json)
  end

  def show
    render json: {
      project: SerializeAdminProject.(@challenge)
    }
  end

  def update
    challenge = Challenge::Update.(@challenge, challenge_params)
    render json: {
      project: SerializeAdminProject.(challenge)
    }
  rescue ActiveRecord::RecordInvalid => e
    render_422(:validation_error, errors: e.record.errors.as_json)
  end

  private
  # The parent's before_action hooks call these, so overriding them swaps
  # in the legacy :project params root and legacy error keys.
  def use_challenge
    @challenge = Challenge.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404(:project_not_found)
  end

  def challenge_params
    params.require(:project).permit(
      :title,
      :slug,
      :description,
      :exercise_slug,
      :unlocked_by_lesson_id
    )
  end
end
