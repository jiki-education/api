class Internal::Settings::HandlesController < Internal::BaseController
  def update
    User::UpdateHandle.(current_user, handle_params[:handle])
    render json: { user: SerializeUser.(current_user) }
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      error: {
        type: :validation_error,
        message: "Handle update failed",
        errors: e.record.errors.as_json
      }
    }, status: :unprocessable_entity
  end

  private
  def handle_params
    params.require(:user).permit(:handle)
  end
end
