class AssistantConversation::AddUserMessage
  include Mandate

  initialize_with :user, :context_type, :context_identifier, :content, :timestamp

  def call
    AssistantConversation::AddMessage.(conversation, "user", content, timestamp)
  end

  memoize
  def conversation = AssistantConversation::FindOrCreate.(user, context_type, context_identifier)
end
