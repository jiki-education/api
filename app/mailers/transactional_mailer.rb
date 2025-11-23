# Transactional emails sent via mail.jiki.io
# - User signup verification
# - Password resets
# - Payment receipts
# - Security alerts
#
# These are critical path emails that MUST be delivered.
# Uses dedicated IP and strict configuration.

class TransactionalMailer < ApplicationMailer
  default from: -> { Jiki.config.mail_from_email }

  # Example: Signup verification email
  # TODO: Implement when User model exists
  # def signup_verification(user)
  #   @user = user
  #   @verification_url = verify_email_url(token: user.email_verification_token)
  #
  #   mail(
  #     to: user.email,
  #     subject: 'Verify your Jiki account'
  #   )
  # end

  # Example: Password reset email
  # TODO: Implement when User model exists
  # def password_reset(user)
  #   @user = user
  #   @reset_url = reset_password_url(token: user.password_reset_token)
  #
  #   mail(
  #     to: user.email,
  #     subject: 'Reset your Jiki password'
  #   )
  # end

  # Example: Payment receipt email
  # TODO: Implement when Payment model exists
  # def payment_receipt(user, payment)
  #   @user = user
  #   @payment = payment
  #
  #   mail(
  #     to: user.email,
  #     subject: "Payment receipt - Jiki #{payment.plan_name}"
  #   )
  # end

  # Welcome email sent after user signs up
  def welcome_email(user)
    @user = user

    mail(
      to: user.email,
      subject: 'Welcome to Jiki!'
    )
  end

  private
  def default_from_email = Jiki.config.mail_from_email
  def configuration_set = Jiki.config.ses_mail_configuration_set
end
