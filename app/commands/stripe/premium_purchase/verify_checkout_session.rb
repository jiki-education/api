class Stripe::PremiumPurchase::VerifyCheckoutSession
  include Mandate

  initialize_with :user, :session_id

  def call
    verify_ownership!
    raise ArgumentError, "Checkout session #{session_id} is not a premium purchase" unless session.mode == "payment"

    # An incomplete session is an expected outcome (declined/abandoned/expired
    # payment), not a bug. Surface the decline code and currency so the UI can
    # offer a precise "retry" CTA.
    raise StripeCheckoutSessionIncompleteError.new(decline_code:, currency: session.currency) unless session.status == "complete"

    # A complete session with an unpaid status is an async payment method (e.g. a
    # bank debit) that is still clearing. The checkout.session.async_payment_*
    # webhooks finish the job once it settles.
    if paid?
      Stripe::PremiumPurchase::Fulfill.(user, session.payment_intent)
    else
      Stripe::PremiumPurchase::MarkPending.(user, session.payment_intent)
    end

    {
      success: true,
      payment_state: paid? ? "paid" : "processing"
    }
  end

  private
  memoize
  def session = ::Stripe::Checkout::Session.retrieve(session_id)

  def paid? = session.payment_status == "paid"

  def verify_ownership!
    metadata_user_id = session.metadata&.[](:user_id) || session.metadata&.[]('user_id')
    return if metadata_user_id.present? && metadata_user_id.to_s == user.id.to_s

    raise SecurityError, "Checkout session does not belong to current user"
  end

  # Best-effort customer-facing decline reason. Returns nil for abandoned or
  # expired sessions with no payment attempt, and never raises.
  def decline_code
    detailed = ::Stripe::Checkout::Session.retrieve(id: session_id, expand: ["payment_intent"])
    Stripe::DetermineDeclineCode.(detailed.payment_intent)
  rescue ::Stripe::StripeError => e
    Rails.logger.warn("Could not determine checkout decline reason for #{session_id}: #{e.message}")
    nil
  end
end
