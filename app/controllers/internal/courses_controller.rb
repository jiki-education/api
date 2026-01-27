class Internal::CoursesController < Internal::BaseController
  skip_before_action :authenticate_user!, only: %i[index show]

  def index
    render json: {
      courses: SerializeCourses.(Course.all)
    }
  end

  def show
    course = Course.find_by!(slug: params[:id])

    render json: {
      course: SerializeCourse.(course)
    }
  rescue ActiveRecord::RecordNotFound
    render_not_found("Course not found")
  end
end
