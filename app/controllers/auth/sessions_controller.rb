class Auth::SessionsController < Devise::SessionsController
  respond_to :json

  OTP_SESSION_TIMEOUT = 5.minutes

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

    # Check if user requires 2FA (admins)
    if resource.requires_otp?
      # store: false above should prevent session creation, but Devise/Warden
      # still persists the user somehow. Explicitly clear it.
      warden.logout(:user)

      # Store OTP session
      session[:otp_user_id] = resource.id
      session[:otp_timestamp] = Time.current.to_i

      return render json: { status: "2fa_required" }, status: :ok if resource.otp_enabled?

      User::GenerateOtpSecret.(resource)
      return render json: {
        status: "2fa_setup_required",
        provisioning_uri: resource.otp_provisioning_uri
      }, status: :ok

    end

    # Non-admin: sign in normally
    sign_in(resource_name, resource)
    respond_with resource, location: after_sign_in_path_for(resource)
  end

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

  def respond_to_on_destroy(non_navigational_status: :no_content)
    # By the time this is called, Devise has already signed out the user
    # so current_user is nil. We just return success.
    # Clear the jiki_user_id cookie explicitly since the ApplicationController's
    # after_action doesn't run when Devise's verify_signed_out_user halts the chain.
    cookies.delete(:jiki_user_id, domain: :all)
    render json: {}, status: non_navigational_status
  end

  def auth_options
    { scope: resource_name, recall: "#{controller_path}#new" }
  end
end
