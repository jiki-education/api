module Auth
  class GoogleOauthController < ApplicationController
    def create
      user = Auth::AuthenticateWithGoogle.(params[:token])

      # Generate JWT tokens (same as login)
      token = Warden::JWTAuth::UserEncoder.new.(user, :user, request.headers['User-Agent'])

      # Generate refresh token
      refresh_token = User::Jwt::CreateRefreshToken.(user)

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
