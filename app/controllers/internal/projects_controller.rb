# LEGACY: pre-rename projects API, identical to the old public surface.
# Kept so front ends deployed before the projects -> challenges rename
# keep working. Delete once the front end has been deployed.
class Internal::ProjectsController < Internal::ChallengesController
  def show
    render json: {
      project: SerializeProject.(@challenge)
    }
  end

  private
  # The parent's before_action hooks call these, so overriding them swaps
  # in the legacy :project_slug param and legacy error keys.
  def use_challenge! = use_project!
end
