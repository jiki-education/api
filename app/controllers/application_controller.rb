class ApplicationController < ActionController::API
  include ActionController::Cookies
  include MetaResponseWrapper

  before_action :set_current_user_agent
  before_action :set_locale
  before_action :extend_session_cookie!
  before_action :set_sentry_user
  after_action :set_user_id_cookie

  private
  # Sets a signed cookie to indicate the user is authenticated.
  # This is used by CloudFlare for cache decisions and by the
  # Next.js frontend for server-side auth checks.
  def set_user_id_cookie
    if user_signed_in?
      cookies.signed[:jiki_user_id] = {
        value: current_user.id,
        domain: :all,
        expires: 10.years,
        httponly: true,
        same_site: :lax,
        secure: Rails.env.production?
      }
    else
      cookies.delete(:jiki_user_id, domain: :all)
    end
  end

  def set_current_user_agent
    Current.user_agent = request.headers["User-Agent"]
  end

  def set_sentry_user
    return unless Rails.env.production? && user_signed_in?

    Sentry.set_user(id: current_user.id)
  end

  # Implement sliding session expiration by touching the session periodically.
  # Without this, the cookie expiry is only set when session data changes,
  # so active users could be logged out after 30 days even if they use the
  # app daily. We throttle to once per hour to reduce unnecessary cookie writes.
  def extend_session_cookie!
    session[:last_seen] = Time.current.to_i if session[:last_seen].nil? || session[:last_seen] < 1.hour.ago.to_i
  end

  def set_locale
    I18n.locale = params[:locale] || current_user&.locale || I18n.default_locale
  end

  def authenticate_user!
    # Don't interfere with Devise's own controllers
    return super if devise_controller?

    # Only allow URL-based authentication in development
    return super unless Rails.env.development?
    return super unless params[:user_id].present?

    # Development-only: Allow authentication via user_id query parameter
    user = User.find_by(id: params[:user_id])
    return super unless user

    sign_in(user, store: false)
    Rails.logger.warn "[DEV AUTH] Authenticated as user #{user.id} via URL parameter"
  end

  def use_lesson!
    @lesson = Lesson.find_by!(slug: params[:lesson_slug])
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: {
        type: "not_found",
        message: "Lesson not found"
      }
    }, status: :not_found
  end

  def use_project!
    @project = Project.find_by!(slug: params[:project_slug])
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: {
        type: "not_found",
        message: "Project not found"
      }
    }, status: :not_found
  end

  def use_concept!
    @concept = Concept.friendly.find(params[:concept_slug])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Concept not found")
  end

  def render_not_found(message)
    render json: {
      error: {
        type: "not_found",
        message: message
      }
    }, status: :not_found
  end

  def render_validation_error(exception)
    render json: {
      error: {
        type: "validation_error",
        message: exception.message
      }
    }, status: :unprocessable_entity
  end

  # Signs in the user, checking for 2FA requirement first.
  # For admin users, stores OTP session and renders 2FA response instead of signing in.
  # For non-admin users, signs in immediately and renders success response.
  def sign_in_with_2fa_guard!(user)
    if user.requires_otp?
      # Clear any existing session before setting up 2FA.
      # This is needed for Devise sessions where warden.authenticate persists the user.
      warden.logout(:user)

      session[:otp_user_id] = user.id
      session[:otp_timestamp] = Time.current.to_i

      if user.otp_enabled?
        render json: { status: "2fa_required" }, status: :ok
      else
        User::GenerateOtpSecret.(user)
        render json: {
          status: "2fa_setup_required",
          provisioning_uri: user.otp_provisioning_uri
        }, status: :ok
      end
      return
    end

    sign_in(user)
    render json: { status: "success", user: SerializeUser.(user) }, status: :ok
  end
end
