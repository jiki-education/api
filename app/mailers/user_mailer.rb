class UserMailer < ApplicationMailer
  # Sends welcome email when user upgrades to Premium
  def welcome_to_premium(user)
    return unless user.data.receive_newsletters?

    with_locale(user) do
      @user = user
      @unsubscribe_key = :newsletters

      mail(
        to: user.email,
        subject: t(".subject")
      )
    end
  end

  # Sends welcome email when user upgrades to Max
  def welcome_to_max(user)
    return unless user.data.receive_newsletters?

    with_locale(user) do
      @user = user
      @unsubscribe_key = :newsletters

      mail(
        to: user.email,
        subject: t(".subject")
      )
    end
  end

  # Sends notification when subscription ends (downgrade to standard)
  def subscription_ended(user)
    return unless user.data.receive_newsletters?

    with_locale(user) do
      @user = user
      @unsubscribe_key = :newsletters

      mail(
        to: user.email,
        subject: t(".subject")
      )
    end
  end
end
