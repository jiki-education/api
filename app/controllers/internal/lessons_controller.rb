class Internal::LessonsController < Internal::BaseController
  before_action :use_lesson!

  def show
    render json: {
      lesson: SerializeLesson.(@lesson, include_data: true)
    }
  end
end
