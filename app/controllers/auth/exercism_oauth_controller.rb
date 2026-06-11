module Auth
  class ExercismOauthController < ApplicationController
    def create
      # Instantiate directly so we can read `payload` after `call` returns.
      # The Exercism userinfo payload contains insider/bootcamp flags that
      # we reconcile AFTER bootstrap to avoid clearing `previously_new_record?`.
      auth = Auth::AuthenticateWithOauth.new(:exercism, params[:code], code_verifier: params[:code_verifier])
      user = auth.()

      if user.previously_new_record?
        User::Bootstrap.(user, "exercism",
          attribution: signup_attribution_params,
          country_code: request.headers["CF-IPCountry"])
      end

      User::Exercism::ReconcileEntitlements.(
        user,
        is_insider: auth.payload['is_insider'] == true,
        is_bootcamp_member: auth.payload['is_bootcamp_member'] == true
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
