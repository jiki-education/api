class Internal::LessonsController < Internal::BaseController
  before_action :use_lesson!

  def show
    render json: {
      lesson: SerializeLesson.(@lesson, current_user, include_data: true)
    }
  end
end
