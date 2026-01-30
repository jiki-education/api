# Premium/subscription-related emails sent via mail.jiki.io
# - Welcome to Premium
# - Welcome to Max
# - Subscription ended
#
# These are transactional emails triggered by payment actions
# that cannot be unsubscribed from.

class PremiumMailer < ApplicationMailer
  self.email_category = :transactional

  # Sends welcome email when user upgrades to Premium
  def welcome_to_premium(user)
    with_locale(user) do
      mail_to_user(
        user,
        to: user.email,
        subject: t(".subject")
      )
    end
  end

  # Sends welcome email when user upgrades to Max
  def welcome_to_max(user)
    with_locale(user) do
      mail_to_user(
        user,
        to: user.email,
        subject: t(".subject")
      )
    end
  end

  # Sends notification when subscription ends (downgrade to standard)
  def subscription_ended(user)
    with_locale(user) do
      mail_to_user(
        user,
        to: user.email,
        subject: t(".subject")
      )
    end
  end
end
