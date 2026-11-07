class Stripe::Webhook::DisputeCreated
  include Mandate

  initialize_with :event

  def call
    return if dispute.payment_intent.blank?

    Stripe::RevokePurchase.(dispute.payment_intent, "disputed")
  end

  private
  memoize
  def dispute = event.data.object
end
