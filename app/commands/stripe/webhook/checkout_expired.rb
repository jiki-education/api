class Stripe::Webhook::CheckoutExpired
  include Mandate

  initialize_with :event

  # Handles checkout.session.expired: the user opened the lifetime Premium
  # checkout and left without paying. Stripe expires an unpaid session after
  # 24 hours by default.
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
