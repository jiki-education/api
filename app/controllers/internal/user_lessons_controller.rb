class Internal::UserLessonsController < Internal::BaseController
  before_action :use_lesson!

  def show
    user_lesson = UserLesson.find_by(user: current_user, lesson: @lesson)

    return render_not_found("User lesson not found") unless user_lesson

    render json: {
      user_lesson: SerializeUserLesson.(user_lesson)
    }
  end

  def start
    UserLesson::Start.(current_user, @lesson)

    render json: {}
  rescue LessonInProgressError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue UserLevelNotFoundError => e
    render json: { error: e.message }, status: :forbidden
  rescue LevelNotCompletedError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def complete
    UserLesson::Complete.(current_user, @lesson)

    render json: {}
  rescue UserLessonNotFoundError => e
    render json: {
      error: {
        type: "user_lesson_not_found",
        message: e.message
      }
    }, status: :unprocessable_entity
  rescue UserLevelNotFoundError => e
    render json: {
      error: {
        type: "user_level_not_found",
        message: e.message
      }
    }, status: :unprocessable_entity
  end
end
