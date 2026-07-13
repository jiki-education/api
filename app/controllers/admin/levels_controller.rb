class Admin::LevelsController < Admin::BaseController
  before_action :set_course
  before_action :set_level, only: [:update]

  def index
    levels = Level::Search.(
      course: @course,
      title: params[:title],
      slug: params[:slug],
      page: params[:page],
      per: params[:per]
    )

    render json: SerializePaginatedCollection.(
      levels,
      serializer: SerializeAdminLevels
    )
  end

  def create
    level = Level::Create.(level_params.merge(course: @course))
    render json: {
      level: SerializeAdminLevel.(level)
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_422(:validation_error, errors: e.record.errors.as_json)
  end

  def update
    level = Level::Update.(@level, level_params)
    render json: {
      level: SerializeAdminLevel.(level)
    }
  rescue ActiveRecord::RecordInvalid => e
    render_422(:validation_error, errors: e.record.errors.as_json)
  end

  private
  def set_course
    return render_400(:missing_course) unless params[:course_slug]

    @course = Course.find_by!(slug: params[:course_slug])
  rescue ActiveRecord::RecordNotFound
    render_404(:course_not_found)
  end

  def set_level
    @level = Level.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404(:level_not_found)
  end

  def level_params
    params.require(:level).permit(:title, :description, :position, :slug, :milestone_summary, :milestone_content)
  end
end
