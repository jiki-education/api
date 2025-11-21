# Base controller for all webhook endpoints
#
# Webhooks don't use the standard Rails authentication stack - instead they
# use signature verification (implementation-specific to each webhook provider).
#
# This base controller provides:
# - ActionController::API inheritance (no session, cookies, views, CSRF)
# - Security logging for audit trail
class Webhooks::BaseController < ActionController::API
  # Log all webhook requests for security auditing
  before_action :log_webhook_request

  private
  def log_webhook_request
    Rails.logger.info(
      "Webhook request: #{self.class.name} from #{request.remote_ip}"
    )
  end
end
