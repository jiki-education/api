class AssistantConversation::FindOrCreate
  include Mandate

  initialize_with :user, :context

  def call
    AssistantConversation.find_or_create_by!(
      user:,
      context:
    ).tap do |conversation|
      track_event! if conversation.previously_new_record?
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
        context_slug: context.try(:slug)
      }.compact
    )
  end
end
