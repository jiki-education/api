# Bulk/marketing emails (mailshots) sent via hello.jiki.io.
# Authored as markdown in the admin and rendered into the shared MJML layout.
# Users unsubscribe via the mailshot's email_communication_preferences_key
# (defaults to :newsletters).
class MailshotMailer < ApplicationMailer
  self.email_category = :marketing

  def send_mailshot(user, mailshot, force: false)
    @mailshot = mailshot
    @header_image = "newsletter.jpg"

    mail_to_user(
      user,
      unsubscribe_key: mailshot.unsubscribe_key,
      force:,
      subject: mailshot.subject
    )
  end
end
