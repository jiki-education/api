class Mailshot::SendToSegment
  include Mandate

  queue_as :mailers

  BATCH_SIZE = 100

  # Keyset (cursor) pagination on users.id rather than offset: rows shifting
  # around mid-send (deletions, segment-exits) can't cause a recipient to be
  # skipped or revisited, and it avoids OFFSET's growing scan cost.
  initialize_with :mailshot, :segment_key, last_id: 0

  def call
    users = mailshot.segment_relation(segment_key).
      where("users.id > ?", last_id).
      order(:id).
      limit(BATCH_SIZE).
      to_a
    return if users.empty?

    users.each { |user| User::Mailshot::Send.(user, mailshot) }

    # TODO: SES daily-quota throttling can be added here — check how many
    # have been sent today and reschedule for tomorrow if over the limit.
    self.class.defer(mailshot, segment_key, last_id: users.last.id, wait: 5.seconds)
  end
end
