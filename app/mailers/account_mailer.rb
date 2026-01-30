# Account-related emails sent via mail.jiki.io
# - Welcome email for new signups
# - Account deletion confirmation
#
# These are transactional emails that cannot be unsubscribed from.

class AccountMailer < ApplicationMailer
  self.email_category = :transactional

  # Sends a welcome email to a new user
  #
  # @param user [User] The user to send the welcome email to
  # @param login_url [String] URL for the user to log in and start learning
  def welcome(user, login_url:)
    @login_url = login_url
    mail_to_user(user)
  end

  # Account deletion confirmation email
  def account_deletion_confirmation(user, confirmation_url:)
    @confirmation_url = confirmation_url
    mail_to_user(user)
  end
end
