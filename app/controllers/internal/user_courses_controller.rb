class Internal::UserCoursesController < Internal::BaseController
  before_action :use_course!, only: %i[show enroll language]
  before_action :use_user_course!, only: %i[show language]

  def index
    render json: {
      user_courses: SerializeUserCourses.(current_user.user_courses)
    }
  end

  def show
    render json: {
      user_course: SerializeUserCourse.(@user_course)
    }
  end

  def enroll
    user_course = UserCourse::Enroll.(current_user, @course)

    render json: {
      user_course: SerializeUserCourse.(user_course)
    }
  end

  def language
    UserCourse::SetLanguage.(@user_course, params[:language])

    render json: {
      user_course: SerializeUserCourse.(@user_course.reload)
    }
  rescue LanguageAlreadyChosenError => e
    render json: { error: { type: "language_already_chosen", message: e.message } }, status: :unprocessable_entity
  rescue InvalidLanguageError => e
    render json: { error: { type: "invalid_language", message: e.message } }, status: :unprocessable_entity
  end

  private
  def use_course!
    @course = Course.find_by!(slug: params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Course not found")
  end

  def use_user_course!
    @user_course = current_user.user_courses.find_by!(course: @course)
  rescue ActiveRecord::RecordNotFound
    render_not_found("Not enrolled in this course")
  end
end
