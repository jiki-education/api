class Internal::UserLessonsController < Internal::BaseController
  before_action :use_lesson!

  def show
    user_lesson = UserLesson.find_by(user: current_user, lesson: @lesson)

    return render_404(:not_found) unless user_lesson

    render json: {
      user_lesson: SerializeUserLesson.(user_lesson)
    }
  end

  def start
    UserLesson::Start.(current_user, @lesson)

    render json: {}
  rescue LessonInProgressError
    render_422(:lesson_in_progress)
  rescue UserLevelNotFoundError
    render_403(:user_level_not_found)
  rescue LevelNotCompletedError
    render_422(:level_not_completed)
  end

  def complete
    UserLesson::Complete.(current_user, @lesson)

    render json: {}
  rescue UserLessonNotFoundError
    render_422(:user_lesson_not_found)
  rescue UserLevelNotFoundError
    render_422(:user_level_not_found)
  end
end
