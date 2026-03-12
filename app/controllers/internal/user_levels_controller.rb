class Internal::UserLevelsController < Internal::BaseController
  before_action :use_course!

  def index
    user_levels = current_user.user_levels.joins(:level).where(levels: { course: @course })

    render json: {
      user_levels: SerializeUserLevels.(user_levels)
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
