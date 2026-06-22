class Mailshot::RenderPreview
  include Mandate

  initialize_with :mailshot, :user

  # Renders the mailshot's markdown inside the full MJML email layout
  # (header/footer/unsubscribe), exactly as it would be sent, without
  # delivering or persisting anything. force: true bypasses opt-out guards
  # so previews always render regardless of the admin's own preferences.
  def call
    MailshotMailer.send_mailshot(user, mailshot, force: true).html_part.body.decoded
  end
end
