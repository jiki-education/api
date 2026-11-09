class User::SendAbandonedCheckoutEmail
  include Mandate

  initialize_with :user

  # This can run 30 minutes after the user closed the checkout, so check
  # Premium here, at send time.
  def call
    return if user.premium?

    User::SendEmail.(user.data, kind: :abandoned_checkout) do
      PremiumMailer.abandoned_checkout(user).deliver_later
    end
  end
end
