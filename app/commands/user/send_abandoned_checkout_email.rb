class User::SendAbandonedCheckoutEmail
  include Mandate

  initialize_with :user

  # This can run 30 minutes after the user closed the checkout, so check
  # Premium and any pending payment (e.g. a bank debit still clearing) here,
  # at send time.
  def call
    return if user.premium?
    return if user.premium_purchase_pending?

    User::SendEmail.(user.data, kind: :abandoned_checkout) do
      PremiumMailer.abandoned_checkout(user).deliver_later
    end
  end
end
