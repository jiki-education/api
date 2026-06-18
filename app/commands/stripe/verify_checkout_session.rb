class Stripe::VerifyCheckoutSession
  include Mandate

  initialize_with :user, :session_id

  def call
    session = ::Stripe::Checkout::Session.retrieve(session_id)

    verify_ownership!(session)

    # An incomplete session is an expected outcome (declined/abandoned/expired payment),
    # not a bug. Surface the decline reason so the UI can be specific.
    raise StripeCheckoutSessionIncompleteError, decline_reason unless session.status == "complete"
    raise ArgumentError, "Checkout session has no subscription" unless session.subscription.present?

    persist_customer_id!(session)

    subscription = ::Stripe::Subscription.retrieve(session.subscription)

    subscription_item = subscription.items.data.first
    raise ArgumentError, "Subscription has no items" unless subscription_item

    interval = Stripe::DetermineSubscriptionDetails.interval_for_price_id(subscription_item.price.id)

    status = Stripe::SyncSubscriptionToUser.(user, subscription, interval)

    Rails.logger.info(
      "Verified checkout session #{session_id} for user #{user.id}: " \
      "premium #{interval} (#{subscription.id}), status: #{status}"
    )

    {
      success: true,
      interval: interval,
      payment_status: session.payment_status,
      subscription_status: status
    }
  end

  private
  def verify_ownership!(session)
    metadata_user_id = session.metadata&.[](:user_id) || session.metadata&.[]('user_id')

    if metadata_user_id.present?
      return if metadata_user_id.to_s == user.id.to_s
    elsif user.data.stripe_customer_id.present? && session.customer == user.data.stripe_customer_id
      return
    end

    raise SecurityError, "Checkout session does not belong to current user"
  end

  def persist_customer_id!(session)
    return if session.customer.blank?

    user.data.with_lock do
      next if user.data.stripe_customer_id.present?

      user.data.update!(stripe_customer_id: session.customer)
    end
  end

  # Best-effort customer-facing decline reason for an incomplete checkout. Returns
  # nil for abandoned/expired sessions with no payment attempt, and never raises -
  # a missing reason just degrades to the generic "payment wasn't completed" message.
  def decline_reason
    declined_payment_intent&.last_payment_error&.message
  rescue ::Stripe::StripeError => e
    Rails.logger.warn("Could not determine checkout decline reason for #{session_id}: #{e.message}")
    nil
  end

  def declined_payment_intent
    detailed = ::Stripe::Checkout::Session.retrieve(
      id: session_id,
      expand: ["payment_intent", "subscription.latest_invoice.payments"]
    )

    # Payment-mode sessions expose the PaymentIntent directly; subscription-mode
    # first payments run through the subscription's latest invoice instead.
    return detailed.payment_intent if detailed.payment_intent

    payment_intent_id =
      detailed.subscription&.latest_invoice&.payments&.data&.first&.payment&.payment_intent
    payment_intent_id ? ::Stripe::PaymentIntent.retrieve(payment_intent_id) : nil
  end
end
