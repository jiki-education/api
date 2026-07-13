class Auth::RegistrationsController < Devise::RegistrationsController
  include TurnstileVerifiable

  respond_to :json

  before_action :verify_turnstile!, only: :create

  def create
    super do |resource|
      if resource.persisted?
        User::Bootstrap.(resource, "email",
          attribution: signup_attribution_params,
          country_code: request.headers["CF-IPCountry"],
          accept_language: request.headers["Accept-Language"])
      end
    end
  end

  def build_resource(hash = {})
    hash[:handle] = User::GenerateHandle.(hash[:email]) if hash[:handle].blank? && hash[:email].present?
    super
  end

  private
  def respond_with(resource, _opts = {})
    if resource.persisted?
      if resource.active_for_authentication?
        # User is confirmed (e.g., OAuth user or pre-confirmed) - return full user data
        render json: { user: SerializeUser.(resource) }, status: :created
      else
        # User needs to confirm email - return minimal data
        render json: { user: { email: resource.email, email_confirmed: false } }, status: :created
      end
    else
      render_422(:validation_error, errors: resource.errors.messages)
    end
  end

  # The frontend can pass an explicit locale choice at signup. An unsupported
  # value is treated as no signal (locale falls back to Accept-Language
  # derivation) rather than failing the registration.
  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation, :name, :handle, :locale).tap do |permitted|
      permitted.delete(:locale) unless I18n::SUPPORTED_LOCALES.include?(permitted[:locale])
    end
  end
end
