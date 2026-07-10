class AssistantConversation::FindOrCreate
  include Mandate

  initialize_with :user, :context

  def call
    # Transitional read-both lookup (see AssistantConversation.for_context):
    # challenge conversations may be stored under either polymorphic name
    # until the backfill migration has run.
    conversation = AssistantConversation.for_context(context).find_by(user:) ||
                   AssistantConversation.create!(user:, context:)

    conversation.tap do |c|
      track_event! if c.previously_new_record?
    end
  end

  private
  def track_event!
    Analytics::TrackEvent.defer(
      user,
      "assistant_conversation_started",
      properties: {
        context_type: context.class.name.downcase,
        context_id: context.id,
        context_slug: context.try(:slug),
        trial: !user.premium?
      }.compact
    )
  end
end
