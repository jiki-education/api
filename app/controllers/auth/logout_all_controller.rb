class Auth::LogoutAllController < ApplicationController
  respond_to :json

  def destroy
    if current_user
      # Revoke ALL JWT tokens and refresh tokens across ALL devices
      current_user.jwt_tokens.destroy_all
      current_user.refresh_tokens.destroy_all
      render json: {}, status: :no_content
    else
      render json: {
        error: {
          type: "unauthorized",
          message: "User has no active session"
        }
      }, status: :unauthorized
    end
  end
end
