class Stripe::Webhook::ChargeRefunded
  include Mandate

  initialize_with :event

  # Only a full refund revokes premium. Partial refunds (e.g. goodwill
  # discounts) leave the purchase in place.
  def call
    return unless charge.refunded
    return if charge.payment_intent.blank?

    Stripe::RevokePurchase.(charge.payment_intent, "refunded")
  end

  private
  memoize
  def charge = event.data.object
end
