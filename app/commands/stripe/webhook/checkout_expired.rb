class Stripe::Webhook::CheckoutExpired
  include Mandate

  initialize_with :event

  # Handles checkout.session.expired: the user opened the lifetime Premium
  # checkout and left without paying. Stripe::CreateCheckoutSessionForPurchase
  # sets sessions to expire after two hours. This catches users who left by
  # closing the tab, so the front-end never sent checkout_closed.
  def call
    return unless session.mode == "payment"
    return unless user

    User::SendAbandonedCheckoutEmail.(user)
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
