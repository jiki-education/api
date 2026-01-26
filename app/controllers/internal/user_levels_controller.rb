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
  rescue LessonIncompleteError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private
  def use_course!
    @course = Course.find_by!(slug: params[:course_slug])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Course not found")
  end

  def use_level!
    slug = params[:level_slug] || params[:id]
    @level = @course.levels.find_by!(slug:)
  rescue ActiveRecord::RecordNotFound
    render_not_found("Level not found")
  end
end
