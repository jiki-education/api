class Stripe::PremiumPurchase::Revoke
  include Mandate

  initialize_with :payment_intent_id, :reason

  def call
    unless payment
      Rails.logger.info("No premium purchase found for PaymentIntent #{payment_intent_id}, nothing to revoke")
      return
    end

    return if payment.data["revoked_at"].present?

    payment.update!(data: payment.data.merge("revoked_at" => Time.current.iso8601, "revoked_reason" => reason))
    User::PremiumEntitlement::Revoke.(payment.user, PremiumEntitlement::STRIPE)

    Rails.logger.info("Revoked premium purchase #{payment_intent_id} for user #{payment.user_id} (#{reason})")
  end

  private
  # Subscription payments are keyed by invoice ID, so only one-off purchases
  # (keyed by PaymentIntent ID) can match here.
  memoize
  def payment = Payment.find_by(payment_processor_id: payment_intent_id)
end
