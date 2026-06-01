module Auth
  class ExercismOauthController < ApplicationController
    def create
      user = Auth::AuthenticateWithExercism.(params[:code], params[:code_verifier])

      User::Bootstrap.(user, "exercism", attribution: signup_attribution_params) if user.previously_new_record?

      sign_in_with_2fa_guard!(user)
    rescue InvalidExercismTokenError => e
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
