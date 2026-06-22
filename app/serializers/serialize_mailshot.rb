class SerializeMailshot
  include Mandate

  initialize_with :mailshot

  def call
    {
      id: mailshot.id,
      slug: mailshot.slug,
      subject: mailshot.subject,
      body_markdown: mailshot.body_markdown,
      email_communication_preferences_key: mailshot.email_communication_preferences_key,
      sent_to_audiences: mailshot.sent_to_audiences,
      sent_count: mailshot.user_mailshots.count,
      created_at: mailshot.created_at.iso8601,
      updated_at: mailshot.updated_at.iso8601
    }
  end
end
