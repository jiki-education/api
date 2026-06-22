class SerializeMailshots
  include Mandate

  initialize_with :mailshots

  def call
    mailshots.map do |mailshot|
      {
        id: mailshot.id,
        slug: mailshot.slug,
        subject: mailshot.subject,
        sent_to_audiences: mailshot.sent_to_audiences,
        sent_count: sent_counts.fetch(mailshot.id, 0),
        created_at: mailshot.created_at.iso8601,
        updated_at: mailshot.updated_at.iso8601
      }
    end
  end

  private
  # Single grouped query for all sent counts, avoiding an N+1 across the page.
  memoize
  def sent_counts
    User::Mailshot.where(mailshot_id: mailshots.map(&:id)).group(:mailshot_id).count
  end
end
