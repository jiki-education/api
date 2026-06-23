class Mailshot::Send
  include Mandate

  initialize_with :mailshot, :segment_key

  def call
    raise Mailshot::UnknownSegmentError, segment_key unless Mailshot::SEGMENTS.key?(segment_key)
    raise Mailshot::BlankBodyError unless mailshot.ready_to_send?

    # Sending the same segment twice is a no-op — the per-user unique index
    # would skip everyone anyway, but this avoids enqueuing pointless work.
    return if mailshot.sent_to_audience?(segment_key)

    mailshot.update!(sent_to_audiences: mailshot.sent_to_audiences + [segment_key])
    Mailshot::SendToSegment.defer(mailshot, segment_key)
  end
end
