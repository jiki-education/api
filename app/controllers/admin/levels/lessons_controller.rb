class Admin::Levels::LessonsController < Admin::BaseController
  before_action :set_level
  before_action :set_lesson, only: [:update]

  def index
    lessons = @level.lessons

    render json: {
      lessons: SerializeAdminLessons.(lessons)
    }
  end

  def create
    lesson = Lesson::Create.(@level, lesson_params)
    render json: {
      lesson: SerializeAdminLesson.(lesson)
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      error: {
        type: "validation_error",
        message: e.message
      }
    }, status: :unprocessable_entity
  end

  def update
    lesson = Lesson::Update.(@lesson, lesson_params)
    render json: {
      lesson: SerializeAdminLesson.(lesson)
    }
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e)
  end

  private
  def set_level
    @level = Level.find(params[:level_id])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Level not found")
  end

  def set_lesson
    @lesson = @level.lessons.find_by!(id: params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Lesson not found")
  end

  def lesson_params
    params.require(:lesson).permit(:slug, :title, :description, :type, :position, data: {})
  end
end
