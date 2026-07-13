class Auth::PasswordsController < Devise::PasswordsController
  include TurnstileVerifiable

  respond_to :json

  before_action :verify_turnstile!, only: :create

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
      render_422(:invalid_token, report: false, errors: resource.errors.messages)
    end
  end

  private
  def resource_params
    params.require(:user).permit(:email, :password, :password_confirmation, :reset_password_token)
  end
end
