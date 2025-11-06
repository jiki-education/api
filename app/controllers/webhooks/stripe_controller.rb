class Webhooks::StripeController < ActionController::API
  # POST /webhooks/stripe
  # Receives and processes Stripe webhook events
  def create
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']

    begin
      # Handle the event (verifies signature and routes to appropriate handler)
      Stripe::Webhook::HandleEvent.(payload, sig_header)

      # Return 200 immediately (Stripe requires fast response)
      head :ok
    rescue Stripe::SignatureVerificationError => e
      # Invalid signature
      Rails.logger.error("Stripe webhook signature verification failed: #{e.message}")
      head :bad_request
    rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::LockWaitTimeout => e
      # Transient errors - let Stripe retry
      Rails.logger.error("Stripe webhook transient error: #{e.message}")
      head :internal_server_error
    rescue StandardError => e
      # Permanent errors - return 200 to prevent retries
      Rails.logger.error("Stripe webhook processing error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      head :ok
    end
  end
end
