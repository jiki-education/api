class AssistantConversation::AddUserMessage
  include Mandate

  initialize_with :user, :context, :content, :timestamp

  def call
    AssistantConversation::AddMessage.(conversation, "user", content, timestamp)
    AwardBadgeJob.perform_later(user, 'sidekick')
  end

  memoize
  def conversation = AssistantConversation::FindOrCreate.(user, context)
end
