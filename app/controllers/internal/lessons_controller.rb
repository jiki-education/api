class Internal::LessonsController < Internal::BaseController
  before_action :use_lesson!

  def show
    render json: {
      lesson: SerializeLesson.(@lesson, include_data: true, language: user_language)
    }
  end

  private
  def user_language
    return nil unless current_user

    course = @lesson.level.course
    user_course = current_user.user_courses.find_by(course:)
    user_course&.language
  end
end
