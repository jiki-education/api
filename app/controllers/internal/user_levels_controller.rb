class Internal::UserLevelsController < Internal::BaseController
  before_action :use_course!
  before_action :use_level!, only: [:complete]

  def index
    user_levels = current_user.user_levels.joins(:level).where(levels: { course: @course })

    render json: {
      user_levels: SerializeUserLevels.(user_levels)
    }
  end

  def complete
    UserLevel::Complete.(current_user, @level)

    render json: {}
  rescue LessonIncompleteError
    render_422(:lesson_incomplete)
  end

  private
  def use_course!
    return render_400(:missing_course) unless params[:course_slug]

    @course = Course.find_by!(slug: params[:course_slug])
  rescue ActiveRecord::RecordNotFound
    render_404(:course_not_found)
  end

  def use_level!
    slug = params[:level_slug] || params[:id]
    @level = Level.find_by!(slug:)
  rescue ActiveRecord::RecordNotFound
    render_404(:level_not_found)
  end
end
