class Admin::ProjectsController < Admin::BaseController
  before_action :use_project, only: %i[show update destroy]

  def index
    projects = Project::Search.(
      title: params[:title],
      page: params[:page],
      per: params[:per]
    )

    render json: SerializePaginatedCollection.(
      projects,
      serializer: SerializeAdminProjects
    )
  end

  def create
    project = Project::Create.(project_params)
    render json: {
      project: SerializeAdminProject.(project)
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_422(:validation_error, errors: e.record.errors.as_json)
  end

  def show
    render json: {
      project: SerializeAdminProject.(@project)
    }
  end

  def update
    project = Project::Update.(@project, project_params)
    render json: {
      project: SerializeAdminProject.(project)
    }
  rescue ActiveRecord::RecordInvalid => e
    render_422(:validation_error, errors: e.record.errors.as_json)
  end

  def destroy
    @project.destroy!
    head :no_content
  end

  private
  def use_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404(:project_not_found)
  end

  def project_params
    params.require(:project).permit(
      :title,
      :slug,
      :description,
      :exercise_slug,
      :unlocked_by_lesson_id
    )
  end
end
