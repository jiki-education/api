class DeviseMailer < Devise::Mailer
  include Devise::Controllers::UrlHelpers
  layout 'mailer'
  default template_path: 'devise/mailer'

  def reset_password_instructions(record, token, _opts = {})
    with_locale(record) do
      @user = record
      @reset_password_url = "#{Jiki.config.frontend_base_url}/auth/reset-password?token=#{token}"

      mail(
        to: record.email,
        from: Devise.mailer_sender,
        subject: I18n.t('devise.mailer.reset_password_instructions.subject')
      )
    end
  end

  private
  def with_locale(user, &block)
    I18n.with_locale(user.locale || I18n.default_locale, &block)
  end
end
