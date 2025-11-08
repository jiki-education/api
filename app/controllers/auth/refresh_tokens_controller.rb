class Auth::RefreshTokensController < ApplicationController
  # POST /auth/refresh
  # Accepts a refresh token and returns a new access token
  def create
    refresh_token_value = params[:refresh_token]

    if refresh_token_value.blank?
      return render json: {
        error: {
          type: "invalid_request",
          message: "Refresh token is required"
        }
      }, status: :bad_request
    end

    # Find the refresh token by hashing the input
    # rubocop:disable Rails/DynamicFindBy
    refresh_token = User::RefreshToken.find_by_token(refresh_token_value)
    # rubocop:enable Rails/DynamicFindBy

    unless refresh_token
      return render json: {
        error: {
          type: "invalid_token",
          message: "Invalid refresh token"
        }
      }, status: :unauthorized
    end

    # Check if the refresh token has expired
    if refresh_token.expired?
      refresh_token.destroy # Clean up expired token
      return render json: {
        error: {
          type: "expired_token",
          message: "Refresh token has expired"
        }
      }, status: :unauthorized
    end

    user = refresh_token.user

    # Set refresh_token_id for JWT payload generation
    Current.refresh_token_id = refresh_token.id

    # Generate a new JWT access token
    # Since we're not going through Devise's dispatch_requests,
    # we need to manually add the token to the allowlist
    token, payload = Warden::JWTAuth::UserEncoder.new.(user, :user, nil)

    # Manually add to allowlist (normally done by on_jwt_dispatch callback)
    user.jwt_tokens.create!(
      jti: payload["jti"],
      aud: payload["aud"],
      refresh_token_id: refresh_token.id,
      expires_at: Time.zone.at(payload["exp"].to_i)
    )

    # Return the new access token in the Authorization header
    response.headers["Authorization"] = "Bearer #{token}"

    render json: {
      message: "Access token refreshed successfully"
    }, status: :ok
  end
end
