class Internal::Profile::AvatarsController < Internal::BaseController
  def update
    User::Avatar::Upload.(current_user, params[:avatar])
    render json: { profile: SerializeProfile.(current_user) }
  rescue InvalidAvatarError
    render_422(:invalid_avatar)
  rescue AvatarTooLargeError
    render_422(:avatar_too_large)
  end

  def destroy
    User::Avatar::Delete.(current_user)
    render json: { profile: SerializeProfile.(current_user) }
  end
end
