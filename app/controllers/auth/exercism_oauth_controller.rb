module Auth
  class ExercismOauthController < ApplicationController
    def create
      payload = Auth::VerifyExercismToken.(params[:code], params[:code_verifier])
      user    = Auth::FindOrCreateFromOauth.(:exercism, payload)

      if user.previously_new_record?
        User::Bootstrap.(user, "exercism",
          attribution: signup_attribution_params,
          country_code: request.headers["CF-IPCountry"])
      end

      User::Exercism::ReconcileEntitlements.(
        user,
        is_insider: payload['is_insider'] == true,
        is_bootcamp_member: payload['is_bootcamp_member'] == true
      )

      sign_in_with_2fa_guard!(user)
    rescue InvalidExercismTokenError, InvalidOauthPayloadError => e
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
