class Mailshot::RenderPreview
  include Mandate

  initialize_with :mailshot, :user

  # Renders the mailshot's markdown inside the full MJML email layout
  # (header/footer/unsubscribe), exactly as it would be sent, without
  # delivering or persisting anything.
  def call
    MailshotMailer.send_mailshot(user, mailshot).html_part.body.decoded
  end
end
