# Premium/subscription-related emails sent via mail.jiki.io
# - Welcome to Premium
# - Subscription ended
#
# These are transactional emails triggered by payment actions
# that cannot be unsubscribed from.

class PremiumMailer < ApplicationMailer
  self.email_category = :transactional

  # Sends welcome email when user upgrades to Premium
  def welcome_to_premium(user)
    mail_to_user(user)
  end

  # Sends notification when subscription ends (downgrade to standard)
  def subscription_ended(user)
    mail_to_user(user)
  end
end
