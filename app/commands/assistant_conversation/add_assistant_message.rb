class AssistantConversation::AddAssistantMessage
  include Mandate

  initialize_with :user, :context, :content, :timestamp, :signature

  def call
    AssistantConversation::VerifyHMAC.(user.id, content, timestamp, signature)

    AssistantConversation::AddMessage.(conversation, "assistant", content, timestamp)
  end

  memoize
  def conversation = AssistantConversation::FindOrCreate.(user, context)
end
