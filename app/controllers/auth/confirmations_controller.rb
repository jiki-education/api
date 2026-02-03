class Auth::ConfirmationsController < Devise::ConfirmationsController
  respond_to :json

  # GET /auth/confirmation?confirmation_token=xxx
  # Confirms the user's email and signs them in
  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])

    if resource.errors.empty?
      sign_in_with_2fa_guard!(resource)
    else
      render_422(:invalid_token)
    end
  end

  # POST /auth/confirmation
  # Resends confirmation email
  def create
    self.resource = resource_class.send_confirmation_instructions(resource_params)

    # Always return success to avoid email enumeration
    render json: { user: { email: resource_params[:email] } }, status: :ok
  end

  private
  def resource_params
    params.require(:user).permit(:email)
  end
end
