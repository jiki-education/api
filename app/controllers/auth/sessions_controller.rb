class Auth::SessionsController < Devise::SessionsController
  respond_to :json

  private
  def respond_with(resource, _opts = {})
    # Generate a refresh token for the user
    refresh_token = User::Jwt::CreateRefreshToken.(resource)

    render json: {
      user: SerializeUser.(resource),
      refresh_token: refresh_token.token
    }, status: :ok
  end

  def respond_with_error
    render json: {
      error: {
        type: "unauthorized",
        message: "Invalid email or password"
      }
    }, status: :unauthorized
  end

  def respond_to_on_destroy
    # Devise JWT automatically handles per-device logout via revoke_jwt
    # which deletes both the JWT and its associated refresh token
    if current_user
      render json: {}, status: :no_content
    else
      render json: {
        error: {
          type: "unauthorized",
          message: "User has no active session"
        }
      }, status: :unauthorized
    end
  end
end
