class Internal::UserLevelsController < Internal::BaseController
  before_action :use_level!, only: [:complete]

  def index
    user_levels = current_user.user_levels

    render json: {
      user_levels: SerializeUserLevels.(user_levels)
    }
  end

  def complete
    UserLevel::Complete.(current_user, @level)

    render json: {}
  rescue LessonIncompleteError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private
  def use_level!
    slug = params[:level_slug] || params[:id]
    @level = Level.find_by!(slug:)
  end
end
