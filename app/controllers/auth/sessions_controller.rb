class Auth::SessionsController < Devise::SessionsController
  respond_to :json

  private
  def respond_with(resource, _opts = {})
    render json: {
      user: SerializeUser.(resource)
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
