class Stripe::VerifyCheckoutSession
  include Mandate

  initialize_with :user, :session_id

  def call
    verify_ownership!

    # An incomplete session is an expected outcome (declined/abandoned/expired payment),
    # not a bug. Surface the decline reason and the attempted price (which encodes
    # interval + currency) so the UI can offer a precise "retry" CTA.
    raise StripeCheckoutSessionIncompleteError.new(decline_reason:, price_id: attempted_price_id) unless session.status == "complete"
    raise ArgumentError, "Checkout session has no subscription" unless session.subscription.present?

    persist_customer_id!

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
      payment_state: payment_state,
      decline_reason: payment_state == "failed" ? first_invoice_payment_intent&.last_payment_error&.message : nil,
      subscription_status: status
    }
  end

  private
  memoize
  def session = ::Stripe::Checkout::Session.retrieve(session_id)

  memoize
  def subscription = ::Stripe::Subscription.retrieve(session.subscription)

  # The price the customer tried to buy, stamped into the session metadata at
  # creation. Encodes both interval and currency, so the front-end can retry the
  # exact plan. Nil for sessions created before this shipped.
  def attempted_price_id
    session.metadata&.[](:price_id) || session.metadata&.[]('price_id')
  end

  def verify_ownership!
    metadata_user_id = session.metadata&.[](:user_id) || session.metadata&.[]('user_id')

    if metadata_user_id.present?
      return if metadata_user_id.to_s == user.id.to_s
    elsif user.data.stripe_customer_id.present? && session.customer == user.data.stripe_customer_id
      return
    end

    raise SecurityError, "Checkout session does not belong to current user"
  end

  def persist_customer_id!
    return if session.customer.blank?

    user.data.with_lock do
      next if user.data.stripe_customer_id.present?

      user.data.update!(stripe_customer_id: session.customer)
    end
  end

  # Disambiguates the "complete but unpaid" Checkout outcome into a three-way
  # signal the front-end can branch on: a still-clearing async payment (processing)
  # vs a declined first payment (failed). "paid"/"no_payment_required" short-circuit
  # so the common case needs no extra Stripe calls.
  memoize
  def payment_state
    return "paid" if session.payment_status.in?(%w[paid no_payment_required])

    case first_invoice_payment_intent&.status
    when "succeeded" then "paid"
    when "requires_payment_method", "canceled" then "failed"
    when "processing", "requires_action", "requires_confirmation" then "processing"
    else first_invoice_payment_intent&.last_payment_error ? "failed" : "processing"
    end
  end

  # The PaymentIntent behind the subscription's first invoice. On Basil+ the invoice
  # no longer exposes payment_intent directly, so it is reached via invoice.payments.
  # Best-effort: returns nil (=> "processing") on any Stripe error rather than raising.
  memoize
  def first_invoice_payment_intent
    invoice_id = subscription.latest_invoice
    return nil if invoice_id.blank?

    invoice = ::Stripe::Invoice.retrieve(id: invoice_id, expand: ["payments"])
    payment_intent_id = invoice.payments&.data&.first&.payment&.payment_intent
    payment_intent_id ? ::Stripe::PaymentIntent.retrieve(payment_intent_id) : nil
  rescue ::Stripe::StripeError => e
    Rails.logger.warn("Could not determine checkout payment state for #{session_id}: #{e.message}")
    nil
  end

  # Best-effort customer-facing decline reason for an incomplete (status != complete)
  # checkout. Returns nil for abandoned/expired sessions with no payment attempt, and
  # never raises - a missing reason degrades to the generic "payment wasn't completed".
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
