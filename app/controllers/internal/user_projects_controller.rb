class Internal::UserProjectsController < Internal::BaseController
  before_action :require_premium!
  before_action :use_project!

  def show
    user_project = UserProject.find_by(user: current_user, project: @project)

    return render_404(:user_project_not_found) unless user_project

    render json: {
      user_project: SerializeUserProject.(user_project)
    }
  end

  def complete
    user_project = UserProject.find_by(user: current_user, project: @project)

    return render_404(:user_project_not_found) unless user_project

    UserProject::Complete.(user_project)

    render json: {}
  end
end
