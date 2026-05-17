module Auth
  class GoogleOauthController < ApplicationController
    def create
      user = Auth::AuthenticateWithGoogle.(params[:code])

      if user.previously_new_record?
        User::Bootstrap.(user)
        User::TrackSignup.(user, "google", attribution: signup_attribution_params)
      end

      sign_in_with_2fa_guard!(user)
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
