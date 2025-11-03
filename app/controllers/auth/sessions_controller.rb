class Auth::SessionsController < Devise::SessionsController
  respond_to :json

  private
  def respond_with(resource, _opts = {})
    # Generate a refresh token for the user
    refresh_token = create_refresh_token(resource)

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
    if current_user
      # Revoke all refresh tokens on logout
      current_user.refresh_tokens.destroy_all
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

  def create_refresh_token(user)
    # Get device info from user agent (optional)
    aud = request.headers["User-Agent"]

    # Create a new refresh token with 30 day expiry
    user.refresh_tokens.create!(
      aud: aud,
      expires_at: 30.days.from_now
    )
  end
end
