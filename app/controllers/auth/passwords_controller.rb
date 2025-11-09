class Auth::PasswordsController < Devise::PasswordsController
  respond_to :json

  def create
    self.resource = resource_class.send_reset_password_instructions(resource_params)

    # Always return success to prevent email enumeration
    render json: {
      message: "Reset instructions sent to #{resource_params[:email]}"
    }, status: :ok
  end

  def update
    self.resource = resource_class.reset_password_by_token(resource_params)

    if resource.errors.empty?
      render json: {
        message: "Password has been reset successfully"
      }, status: :ok
    else
      render json: {
        error: {
          type: "invalid_token",
          message: "Reset token is invalid or has expired",
          errors: resource.errors.messages
        }
      }, status: :unprocessable_entity
    end
  end

  private
  def resource_params
    params.require(:user).permit(:email, :password, :password_confirmation, :reset_password_token)
  end
end
