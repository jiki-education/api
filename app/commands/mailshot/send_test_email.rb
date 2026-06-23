class Mailshot::SendTestEmail
  include Mandate

  initialize_with :mailshot, :user

  # Sends the mailshot to a single admin through the normal send pipeline.
  # Any existing send record for this user is deleted first so the test can
  # be repeated (the unique index would otherwise dedup it away).
  def call
    raise ArgumentError, "Test sends can only be sent to admins" unless user.admin?

    mailshot.user_mailshots.where(user:).destroy_all
    User::Mailshot::Send.(user, mailshot)
  end
end
