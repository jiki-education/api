# Premium/subscription-related emails sent via mail.jiki.io
# - Welcome to Premium
# - Subscription ended
# - Abandoned checkout (a one-off offer of help)
#
# These are transactional emails triggered by payment actions
# that cannot be unsubscribed from.

class PremiumMailer < ApplicationMailer
  self.email_category = :transactional

  # Sends welcome email when user upgrades to Premium
  def welcome_to_premium(user)
    @header_image = "premium-welcome.jpg"
    mail_to_user(user)
  end

  # Sends notification when subscription ends (downgrade to standard)
  def subscription_ended(user)
    mail_to_user(user)
  end

  # Offers help once to a user who opened the lifetime checkout but didn't pay
  def abandoned_checkout(user)
    mail_to_user(user)
  end
end
