class AssistantConversation::CheckUserAccess
  include Mandate

  initialize_with :user, :context

  def call
    return true if user.premium?

    # Standard users: only allowed for their "free" lesson
    most_recent = most_recent_lesson_conversation

    # If no previous conversation, this lesson becomes the free one
    return true if most_recent.nil?

    # If previous conversation exists, must be same lesson
    most_recent.context_id == context.id && most_recent.context_type == context.class.name
  end

  private
  # Scoped to lessons only. Challenge chat is premium-only (require_premium! on
  # every challenge controller), so a standard user never reaches CheckUserAccess
  # with a Challenge context. Keeping this lesson-scoped means a user who was
  # premium, had challenge conversations, then downgraded still gets a fresh free
  # lesson — their past challenge chats don't burn the standard-tier allowance.
  memoize
  def most_recent_lesson_conversation
    user.assistant_conversations.
      where(context_type: 'Lesson').
      order(updated_at: :desc).
      first
  end
end
