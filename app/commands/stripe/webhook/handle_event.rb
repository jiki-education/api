class Stripe::Webhook::HandleEvent
  include Mandate

  initialize_with :payload, :signature

  def call
    # Route to appropriate handler based on event type
    case event.type
    when 'checkout.session.completed'
      Stripe::Webhook::CheckoutCompleted.(event)
    when 'customer.subscription.created'
      Stripe::Webhook::SubscriptionCreated.(event)
    when 'customer.subscription.updated'
      Stripe::Webhook::SubscriptionUpdated.(event)
    when 'customer.subscription.deleted'
      Stripe::Webhook::SubscriptionDeleted.(event)
    when 'invoice.payment_succeeded'
      Stripe::Webhook::InvoicePaymentSucceeded.(event)
    when 'invoice.payment_failed'
      Stripe::Webhook::InvoicePaymentFailed.(event)
    else
      # Log unhandled event types for debugging
      Rails.logger.info("Unhandled Stripe webhook event: #{event.type}")
    end
  end

  private
  memoize
  def event
    ::Stripe::Webhook.construct_event(
      payload,
      signature,
      Jiki.secrets.stripe_webhook_secret
    )
  end
end
