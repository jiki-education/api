class Internal::UserLevelsController < Internal::BaseController
  def index
    user_levels = current_user.user_levels

    render json: {
      user_levels: SerializeUserLevels.(user_levels)
    }
  end
end
