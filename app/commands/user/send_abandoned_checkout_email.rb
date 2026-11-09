class User::SendAbandonedCheckoutEmail
  include Mandate

  initialize_with :user

  def call
    User::SendEmail.(user.data, kind: :abandoned_checkout) do
      PremiumMailer.abandoned_checkout(user).deliver_later
    end
  end
end
