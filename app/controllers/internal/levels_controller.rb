class Internal::LevelsController < Internal::BaseController
  def index
    render json: {
      levels: SerializeLevels.(Level.all)
    }
  end
end
