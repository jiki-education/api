class Stripe::Webhook::PremiumPurchaseFailed
  include Mandate

  initialize_with :event

  # Handles checkout.session.async_payment_failed: a delayed payment (e.g. a
  # bank debit) didn't clear, so the user can try again.
  def call
    return unless session.mode == "payment"

    unless user
      Rails.logger.error("Premium purchase #{session.id} failed but user not found")
      return
    end

    Stripe::PremiumPurchase::ClearPending.(user, session.payment_intent)
    Rails.logger.info("Premium purchase #{session.id} failed for user #{user.id}")
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
