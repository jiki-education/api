class User::Mailshot::Send
  include Mandate

  initialize_with :user, :mailshot

  def call
    user_mailshot = create_record!

    # If the record already existed, this user has already been sent this
    # mailshot. The unique index on [user_id, mailshot_id] is the guarantee
    # that no user ever receives a duplicate, even across overlapping
    # segments, retried jobs or concurrent batches.
    return unless user_mailshot

    User::SendEmail.(user_mailshot) do
      MailshotMailer.send_mailshot(user, mailshot).deliver_later
    end
  end

  private
  def create_record!
    user.user_mailshots.create!(mailshot:)
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
