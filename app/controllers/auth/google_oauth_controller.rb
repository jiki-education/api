module Auth
  class GoogleOauthController < ApplicationController
    def create
      Rails.logger.info "[GoogleOAuthController] Received Google OAuth request"
      Rails.logger.debug "[GoogleOAuthController] Params: code=#{params[:code]&.[](0..10)}..."

      user = Auth::AuthenticateWithGoogle.(params[:code])

      Rails.logger.info "[GoogleOAuthController] User authenticated: #{user.email}"

      # Generate JWT access token
      # Since we're not going through Devise's dispatch_requests,
      # we need to manually add the token to the allowlist
      # Note: User-Agent is already set in Current.user_agent by ApplicationController
      token, payload = Warden::JWTAuth::UserEncoder.new.(user, :user, nil)

      Rails.logger.debug "[GoogleOAuthController] Generated JWT payload: jti=#{payload['jti']}"

      # Generate refresh token
      refresh_token = User::Jwt::CreateRefreshToken.(user)

      # Manually add JWT to allowlist (normally done by on_jwt_dispatch callback)
      User::Jwt::CreateToken.(user, payload, refresh_token_id: refresh_token.id)

      response.headers['Authorization'] = "Bearer #{token}"

      Rails.logger.info "[GoogleOAuthController] Successfully created session for user: #{user.id}"

      render json: {
        user: SerializeUser.(user),
        refresh_token: refresh_token.token
      }, status: :ok
    rescue InvalidGoogleTokenError => e
      Rails.logger.error "[GoogleOAuthController] Google token error: #{e.message}"
      render json: {
        error: {
          type: :invalid_token,
          message: e.message
        }
      }, status: :unauthorized
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "[GoogleOAuthController] Validation error: #{e.record.errors.full_messages}"
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
