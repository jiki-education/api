class Internal::LevelsController < Internal::BaseController
  before_action :use_course!

  def index
    render json: {
      levels: SerializeLevels.(@course.levels)
    }
  end

  private
  def use_course!
    return render_400(:missing_course) unless params[:course_slug]

    @course = Course.find_by!(slug: params[:course_slug])
  rescue ActiveRecord::RecordNotFound
    render_404(:course_not_found)
  end
end
