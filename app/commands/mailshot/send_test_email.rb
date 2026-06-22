class Mailshot::SendTestEmail
  include Mandate

  initialize_with :mailshot, :user

  # Sends the mailshot to a single user (an admin) without creating a
  # User::Mailshot record, so test sends never count as a real send and
  # never affect dedup. force: true bypasses the recipient's opt-out so
  # the test always arrives.
  def call
    MailshotMailer.send_mailshot(user, mailshot, force: true).deliver_later
  end
end
