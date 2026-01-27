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
    render_validation_error(e)
  end

  def update
    level = Level::Update.(@level, level_params)
    render json: {
      level: SerializeAdminLevel.(level)
    }
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e)
  end

  private
  def set_course
    unless params[:course_slug]
      return render json: { error: { type: "missing_course", message: "course_slug parameter required" } },
        status: :bad_request
    end

    @course = Course.find_by!(slug: params[:course_slug])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Course not found")
  end

  def set_level
    @level = Level.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Level not found")
  end

  def level_params
    params.require(:level).permit(:title, :description, :position, :slug, :milestone_summary, :milestone_content)
  end
end
