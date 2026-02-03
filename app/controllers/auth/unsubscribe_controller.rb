# Handles email unsubscribe requests via one-click unsubscribe links
#
# RFC 8058 one-click unsubscribe: POST request with unsubscribe token
class Auth::UnsubscribeController < ApplicationController
  def create
    user = User::Unsubscribe.(params[:token])
    render json: { unsubscribed: true, email: user.email }, status: :ok
  rescue InvalidUnsubscribeTokenError
    render_404(:invalid_unsubscribe_token)
  end
end
