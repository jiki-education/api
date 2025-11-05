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
    rescue StandardError => e
      # Log other errors but still return 200 to Stripe
      # (We don't want Stripe to retry if it's our bug)
      Rails.logger.error("Stripe webhook processing error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      head :ok
    end
  end
end
