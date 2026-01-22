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
      render json: { user: SerializeUser.(resource) }, status: :created
    else
      render json: {
        error: {
          type: "validation_error",
          message: "Validation failed",
          errors: resource.errors.messages
        }
      }, status: :unprocessable_entity
    end
  end

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation, :name, :handle)
  end
end
