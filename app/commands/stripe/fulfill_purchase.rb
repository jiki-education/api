class Stripe::FulfillPurchase
  include Mandate

  initialize_with :user, :payment_intent_id

  # Both the verify endpoint and the webhooks call this, possibly at the same
  # time, so every step is idempotent.
  def call
    revoked = payment.data["revoked_at"].present?
    Stripe::ClearPendingPurchase.(user, payment_intent_id)
    link_customer!
    return if revoked

    grant!
  end

  private
  # Checkout creates the Customer when a first-time buyer pays, so this is the
  # first point where the user can be linked to it.
  def link_customer!
    customer_id = payment.data["stripe_customer_id"]
    return if customer_id.blank?
    return if user.data.stripe_customer_id.present?

    user.data.update!(stripe_customer_id: customer_id)
    # Matches the name and metadata given by Stripe::GetOrCreateCustomer
    ::Stripe::Customer.update(customer_id, name: user.handle, metadata: { user_id: user.id, handle: user.handle })
  rescue ::Stripe::StripeError => e
    # The name and metadata only help when browsing Stripe, so a failure here
    # must not stop the user getting Premium.
    Rails.logger.warn("Could not set metadata on Stripe customer #{customer_id} for user #{user.id}: #{e.message}")
  end

  def grant!
    User::PremiumEntitlement::Grant.(user, PremiumEntitlement::STRIPE_PURCHASE)
  rescue ActiveRecord::RecordNotUnique
    # A concurrent fulfilment created the entitlement first, and that call
    # handles the upgrade.
  end

  memoize
  def payment
    user.payments.find_by(payment_processor_id: payment_intent_id) || create_payment!
  end

  def create_payment!
    raise ArgumentError, "PaymentIntent #{payment_intent_id} has not succeeded" unless payment_intent.status == "succeeded"

    user.payments.create!(
      payment_processor_id: payment_intent.id,
      amount_in_cents: payment_intent.amount_received,
      currency: payment_intent.currency,
      product: 'premium',
      external_receipt_url: charge&.receipt_url,
      data: {
        purchase_type: 'lifetime',
        stripe_payment_intent_id: payment_intent.id,
        stripe_charge_id: charge&.id,
        stripe_customer_id: payment_intent.customer,
        revoked_at: already_revoked? ? Time.current.iso8601 : nil,
        revoked_reason: revoked_reason
      }.compact
    )
  rescue ActiveRecord::RecordNotUnique
    user.payments.find_by!(payment_processor_id: payment_intent_id)
  end

  # A refund or dispute can land before the purchase is first recorded (e.g. if
  # fulfilment kept failing), so check the charge rather than granting blindly.
  def already_revoked? = revoked_reason.present?

  memoize
  def revoked_reason
    return "refunded" if charge&.refunded
    return "disputed" if charge&.disputed

    nil
  end

  memoize
  def payment_intent = ::Stripe::PaymentIntent.retrieve(id: payment_intent_id, expand: ["latest_charge"])

  def charge = payment_intent.latest_charge
end
