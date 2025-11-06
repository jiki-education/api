class Internal::ProjectsController < Internal::BaseController
  before_action :use_project!, only: [:show]

  def index
    projects = Project::Search.(
      title: params[:title],
      page: params[:page],
      per: params[:per],
      user: current_user
    )

    render json: SerializePaginatedCollection.(
      projects,
      serializer: SerializeProjects,
      serializer_kwargs: { for_user: current_user }
    )
  end

  def show
    render json: {
      project: SerializeProject.(@project)
    }
  end
end
