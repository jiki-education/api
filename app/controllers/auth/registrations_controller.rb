class Auth::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  def create
    super do |resource|
      User::Bootstrap.(resource) if resource.persisted?
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

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation, :name, :handle)
  end
end
