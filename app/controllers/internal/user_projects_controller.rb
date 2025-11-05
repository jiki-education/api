class Internal::UserProjectsController < Internal::BaseController
  before_action :use_project!

  def show
    user_project = UserProject.find_by(user: current_user, project: @project)

    return render_not_found("User project not found") unless user_project

    render json: {
      user_project: SerializeUserProject.(user_project)
    }
  end
end
