module Auth
  class GoogleOauthController < ApplicationController
    def create
      user = Auth::AuthenticateWithGoogle.(params[:code])

      # Sign in the user (creates session cookie automatically)
      sign_in(user)

      render json: { user: SerializeUser.(user) }, status: :ok
    rescue InvalidGoogleTokenError => e
      render json: {
        error: {
          type: :invalid_token,
          message: e.message
        }
      }, status: :unauthorized
    rescue ActiveRecord::RecordInvalid => e
      render json: {
        error: {
          type: :validation_error,
          message: "Could not create user account",
          errors: e.record.errors.messages
        }
      }, status: :unprocessable_entity
    end
  end
end
