class Internal::Profile::AvatarsController < Internal::BaseController
  def update
    User::Avatar::Upload.(current_user, params[:avatar])
    render json: { profile: SerializeProfile.(current_user) }
  rescue InvalidAvatarError, AvatarTooLargeError => e
    render json: { error: { type: :validation_error, message: e.message } },
      status: :unprocessable_entity
  end

  def destroy
    User::Avatar::Delete.(current_user)
    render json: { profile: SerializeProfile.(current_user) }
  end
end
