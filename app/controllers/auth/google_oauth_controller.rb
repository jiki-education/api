module Auth
  class GoogleOauthController < ApplicationController
    def create
      payload = Auth::VerifyGoogleToken.(params[:code])
      user    = Auth::FindOrCreateFromOauth.(:google, payload)

      if user.previously_new_record?
        User::Bootstrap.(user, "google",
          attribution: signup_attribution_params,
          country_code: request.headers["CF-IPCountry"])
      end

      sign_in_with_2fa_guard!(user)
    rescue InvalidGoogleTokenError, InvalidOauthPayloadError => e
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
