class Stripe::Webhook::PremiumPurchaseCompleted
  include Mandate

  initialize_with :event

  # Handles checkout.session.completed for payment-mode sessions, and
  # checkout.session.async_payment_succeeded once a delayed payment clears.
  def call
    return unless session.mode == "payment"

    unless user
      Rails.logger.error("Premium purchase #{session.id} completed but user not found")
      return
    end

    if session.payment_status == "paid"
      Stripe::PremiumPurchase::Fulfill.(user, session.payment_intent)
    else
      Rails.logger.info("Premium purchase #{session.id} completed but not yet paid (#{session.payment_status})")
      Stripe::PremiumPurchase::MarkPending.(user, session.payment_intent)
    end
  end

  private
  memoize
  def session = event.data.object

  memoize
  def user
    user_id = session.metadata&.[](:user_id) || session.metadata&.[]('user_id')
    user_id.present? ? User.find_by(id: user_id) : nil
  end
end
