class AssistantConversation::AddAssistantMessage
  include Mandate

  initialize_with :user, :context_type, :context_identifier, :content, :timestamp, :signature

  def call
    AssistantConversation::VerifyHMAC.(user.id, content, timestamp, signature)

    AssistantConversation::AddMessage.(conversation, "assistant", content, timestamp)
  end

  memoize
  def conversation = AssistantConversation::FindOrCreate.(user, context_type, context_identifier)
end
