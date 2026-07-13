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
    render_422(:validation_error, errors: e.record.errors.as_json)
  end

  def update
    lesson = Lesson::Update.(@lesson, lesson_params)
    render json: {
      lesson: SerializeAdminLesson.(lesson)
    }
  rescue ActiveRecord::RecordInvalid => e
    render_422(:validation_error, errors: e.record.errors.as_json)
  end

  private
  def set_level
    @level = Level.find(params[:level_id])
  rescue ActiveRecord::RecordNotFound
    render_404(:level_not_found)
  end

  def set_lesson
    @lesson = @level.lessons.find_by!(id: params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404(:lesson_not_found)
  end

  def lesson_params
    params.require(:lesson).permit(:slug, :title, :description, :type, :position, data: {})
  end
end
