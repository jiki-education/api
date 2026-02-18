class AssistantConversation::CheckUserAccess
  include Mandate

  initialize_with :user, :lesson

  def call
    return true if user.premium?

    # Standard users: only allowed for their "free" lesson
    most_recent = most_recent_lesson_conversation

    # If no previous conversation, this lesson becomes the free one
    return true if most_recent.nil?

    # If previous conversation exists, must be same lesson
    most_recent.context_id == lesson.id && most_recent.context_type == 'Lesson'
  end

  private
  memoize
  def most_recent_lesson_conversation
    user.assistant_conversations.
      where(context_type: 'Lesson').
      order(updated_at: :desc).
      first
  end
end
