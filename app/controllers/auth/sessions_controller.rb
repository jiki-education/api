class Auth::SessionsController < Devise::SessionsController
  respond_to :json

  private
  def respond_with(resource, _opts = {})
    render json: { user: SerializeUser.(resource) }, status: :ok
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
    # By the time this is called, Devise has already signed out the user
    # so current_user is nil. We just return success.
    render json: {}, status: :no_content
  end
end
