class AssistantConversation::FindOrCreate
  include Mandate

  initialize_with :user, :context

  def call
    AssistantConversation.find_or_create_by!(
      user:,
      context:
    )
  end
end
