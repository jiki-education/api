# Authentication emails via Devise
# - Email confirmation
# - Password reset
#
# These are transactional emails that cannot be unsubscribed from.

class DeviseMailer < ApplicationMailer
  include Devise::Controllers::UrlHelpers
  default template_path: 'devise/mailer'

  self.email_category = :transactional

  def confirmation_instructions(record, token, _opts = {})
    @user = record
    @confirmation_url = "#{Jiki.config.frontend_base_url}/auth/confirm-email?token=#{token}"

    I18n.with_locale(record.locale) do
      mail(
        to: record.unconfirmed_email || record.email,
        subject: I18n.t('devise.mailer.confirmation_instructions.subject')
      )
    end
  end

  def reset_password_instructions(record, token, _opts = {})
    @user = record
    @reset_password_url = "#{Jiki.config.frontend_base_url}/auth/reset-password?token=#{token}"

    I18n.with_locale(record.locale) do
      mail(
        to: record.email,
        subject: I18n.t('devise.mailer.reset_password_instructions.subject')
      )
    end
  end
end
