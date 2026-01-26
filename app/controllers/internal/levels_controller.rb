class Internal::LevelsController < Internal::BaseController
  before_action :use_course!
  before_action :use_level!, only: [:milestone]

  def index
    render json: {
      levels: SerializeLevels.(@course.levels)
    }
  end

  def milestone
    render json: {
      milestone: SerializeLevelMilestone.(@level)
    }
  end

  private
  def use_course!
    unless params[:course_slug]
      return render json: { error: { type: "missing_course", message: "course_slug parameter required" } },
        status: :bad_request
    end

    @course = Course.find_by!(slug: params[:course_slug])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Course not found")
  end

  def use_level!
    @level = Level.find_by!(slug: params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Level not found")
  end
end
