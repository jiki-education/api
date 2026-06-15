class Auth::SessionsController < Devise::SessionsController
  include TurnstileVerifiable

  respond_to :json

  OTP_SESSION_TIMEOUT = 5.minutes

  before_action :verify_turnstile!, only: :create

  # Override create to intercept admin logins for 2FA
  def create
    # Authenticate without signing in (store: false prevents session creation)
    self.resource = warden.authenticate(auth_options.merge(store: false))

    # Handle authentication failure
    return respond_with_error if resource.blank?

    # Handle unconfirmed users (same as before)
    unless resource.active_for_authentication?
      return render json: {
        error: { type: "unconfirmed", email: resource.email }
      }, status: :unauthorized
    end

    sign_in_with_2fa_guard!(resource, sign_in_type: :login)
  end

  private
  def respond_with_error
    render_401(:invalid_credentials)
  end

  def respond_to_on_destroy(non_navigational_status: :no_content)
    # By the time this is called, Devise has already signed out the user
    # so current_user is nil. We just return success.
    # Clear the user id cookie explicitly since the ApplicationController's
    # after_action doesn't run when Devise's verify_signed_out_user halts the chain.
    cookies.delete(ApplicationController::USER_ID_COOKIE_NAME, domain: :all)
    render json: {}, status: non_navigational_status
  end

  def auth_options
    { scope: resource_name, recall: "#{controller_path}#new" }
  end
end
