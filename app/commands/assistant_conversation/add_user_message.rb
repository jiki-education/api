class AssistantConversation::AddUserMessage
  include Mandate

  initialize_with :user, :context, :content, :timestamp

  def call
    AssistantConversation::AddMessage.(conversation, "user", content, timestamp)
    AwardBadgeJob.perform_later(user, 'collaborator')
  end

  memoize
  def conversation = AssistantConversation::FindOrCreate.(user, context)
end
