class Mailshot::SendToSegment
  include Mandate

  queue_as :mailers

  BATCH_SIZE = 100

  initialize_with :mailshot, :segment_key, limit: BATCH_SIZE, offset: 0

  def call
    users = mailshot.segment_relation(segment_key).order(:id).offset(offset).limit(limit).to_a
    return if users.empty?

    users.each { |user| User::Mailshot::Send.(user, mailshot) }

    # TODO: SES daily-quota throttling can be added here — check how many
    # have been sent today and reschedule for tomorrow if over the limit.
    self.class.defer(mailshot, segment_key, limit:, offset: offset + limit, wait: 5.seconds)
  end
end
