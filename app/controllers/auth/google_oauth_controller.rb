module Auth
  class GoogleOauthController < ApplicationController
    def create
      user = Auth::AuthenticateWithGoogle.(params[:code])

      # Generate JWT access token
      # Since we're not going through Devise's dispatch_requests,
      # we need to manually add the token to the allowlist
      # Note: User-Agent is already set in Current.user_agent by ApplicationController
      token, payload = Warden::JWTAuth::UserEncoder.new.(user, :user, nil)

      # Generate refresh token
      refresh_token = User::Jwt::CreateRefreshToken.(user)

      User::Jwt::CreateToken.(user, payload, refresh_token_id: refresh_token.id)

      response.headers['Authorization'] = "Bearer #{token}"

      render json: {
        user: SerializeUser.(user),
        refresh_token: refresh_token.token
      }, status: :ok
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
