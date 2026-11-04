class Stripe::Webhook::HandleEvent
  include Mandate

  initialize_with :payload, :signature

  def call
    # Route to appropriate handler based on event type
    case event.type
    when 'checkout.session.completed'
      if event.data.object.mode == 'payment'
        Stripe::Webhook::PurchaseCompleted.(event)
      else
        Stripe::Webhook::CheckoutCompleted.(event)
      end
    when 'checkout.session.async_payment_succeeded'
      Stripe::Webhook::PurchaseCompleted.(event)
    when 'checkout.session.async_payment_failed'
      Stripe::Webhook::PurchaseFailed.(event)
    when 'charge.refunded'
      Stripe::Webhook::ChargeRefunded.(event)
    when 'charge.dispute.created'
      Stripe::Webhook::DisputeCreated.(event)
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
