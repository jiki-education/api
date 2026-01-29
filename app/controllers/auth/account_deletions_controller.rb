class Auth::AccountDeletionsController < ApplicationController
  before_action :authenticate_user!, only: [:request_deletion]

  # POST /auth/account_deletion/request
  # Initiates account deletion by sending confirmation email
  # Requires authentication
  def request_deletion
    AccountDeletion::RequestDeletion.(current_user)
    render json: {}, status: :ok
  end

  # POST /auth/account_deletion/confirm
  # Finalizes account deletion after token validation
  # Does not require authentication (token is the auth)
  def confirm
    AccountDeletion::ConfirmDeletion.(params[:token])

    # Sign out if logged in and clear cookies
    sign_out(current_user) if user_signed_in?
    cookies.delete(:jiki_user_id, domain: :all)

    render json: {}, status: :ok
  rescue AccountDeletion::ValidateDeletionToken::InvalidTokenError
    render json: {
      error: {
        type: "invalid_token",
        message: "Invalid or expired deletion token"
      }
    }, status: :unprocessable_entity
  rescue AccountDeletion::ValidateDeletionToken::TokenExpiredError
    render json: {
      error: {
        type: "token_expired",
        message: "Deletion token has expired"
      }
    }, status: :unprocessable_entity
  rescue StripeSubscriptionCancellationError
    render json: {
      error: {
        type: "stripe_error",
        message: "Could not cancel your subscription. Please try again or contact support."
      }
    }, status: :service_unavailable
  end
end
