class Internal::UserProjectsController < Internal::BaseController
  before_action :require_premium!
  before_action :use_project!
  before_action :use_user_project!

  def show
    render json: {
      user_project: SerializeUserProject.(@user_project)
    }
  end

  def complete
    UserProject::Complete.(@user_project)

    render json: {}
  end
end
