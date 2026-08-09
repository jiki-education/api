module Auth
  class GoogleOauthController < ApplicationController
    def create
      payload = Auth::VerifyGoogleToken.(params[:code])
      user    = Auth::FindOrCreateFromOauth.(:google, payload)

      if user.previously_new_record?
        User::Bootstrap.(user, "google",
          attribution: signup_attribution_params,
          country_code: request.headers["CF-IPCountry"],
          accept_language: request.headers["Accept-Language"])
      end

      sign_in_with_2fa_guard!(user, sign_in_type: user.previously_new_record? ? :signup : :login)
    rescue InvalidGoogleTokenError, InvalidOauthPayloadError
      render json: {
        error: { type: :invalid_token }
      }, status: :unauthorized
    rescue ActiveRecord::RecordInvalid => e
      render json: {
        error: {
          type: :validation_error,
          errors: e.record.errors.details
        }
      }, status: :unprocessable_entity
    end
  end
end
