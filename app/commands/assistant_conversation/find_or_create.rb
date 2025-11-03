class AssistantConversation::FindOrCreate
  include Mandate

  initialize_with :user, :context_type, :context_identifier

  def call
    AssistantConversation.find_or_create_by!(
      user:,
      context_type:,
      context_identifier:
    )
  end
end
