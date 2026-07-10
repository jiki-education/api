# LEGACY: pre-rename projects API, identical to the old public surface.
# Kept so front ends deployed before the projects -> challenges rename
# keep working. Delete once the front end has been deployed.
class Internal::UserProjectsController < Internal::UserChallengesController
  def show
    render json: {
      user_project: SerializeUserProject.(@user_challenge)
    }
  end

  def start
    UserChallenge::Start.(current_user, @challenge)

    render json: {}
  rescue ChallengeLockedError
    render_403(:project_locked)
  end

  private
  # The parent's before_action hooks call these, so overriding them swaps
  # in the legacy :project_slug param and legacy error keys.
  def use_challenge! = use_project!
  def use_user_challenge! = use_user_project!
end
