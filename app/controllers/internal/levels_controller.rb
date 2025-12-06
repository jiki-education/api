class Internal::LevelsController < Internal::BaseController
  before_action :use_level!, only: [:milestone]

  def index
    render json: {
      levels: SerializeLevels.(Level.all)
    }
  end

  def milestone
    render json: {
      milestone: SerializeLevelMilestone.(@level)
    }
  end

  private
  def use_level!
    @level = Level.find_by!(slug: params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Level not found")
  end
end
