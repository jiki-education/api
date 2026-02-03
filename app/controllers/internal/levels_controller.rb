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
    return render_400(:missing_course) unless params[:course_slug]

    @course = Course.find_by!(slug: params[:course_slug])
  rescue ActiveRecord::RecordNotFound
    render_404(:course_not_found)
  end

  def use_level!
    @level = Level.find_by!(slug: params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404(:level_not_found)
  end
end
