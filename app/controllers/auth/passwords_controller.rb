class Auth::PasswordsController < Devise::PasswordsController
  respond_to :json

  def create
    self.resource = resource_class.send_reset_password_instructions(resource_params)

    # Always return success to prevent email enumeration
    render_success(:password_reset_sent, email: resource_params[:email])
  end

  def update
    self.resource = resource_class.reset_password_by_token(resource_params)

    if resource.errors.empty?
      render_success(:password_reset_success)
    else
      render_422(:invalid_token, errors: resource.errors.messages)
    end
  end

  private
  def resource_params
    params.require(:user).permit(:email, :password, :password_confirmation, :reset_password_token)
  end
end
