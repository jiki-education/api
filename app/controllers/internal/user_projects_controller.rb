class Internal::UserProjectsController < Internal::BaseController
  before_action :require_premium!
  before_action :use_project!
  before_action :use_user_project!, only: %i[show complete]

  def show
    render json: {
      user_project: SerializeUserProject.(@user_project)
    }
  end

  def start
    UserProject::Start.(current_user, @project)

    render json: {}
  rescue ProjectLockedError
    render_403(:project_locked)
  end

  def complete
    UserProject::Complete.(@user_project)

    render json: {}
  end
end
