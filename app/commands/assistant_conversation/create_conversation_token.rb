class AssistantConversation::CreateConversationToken
  include Mandate

  initialize_with :user, :lesson

  def call
    unless AssistantConversation::CheckUserAccess.(user, lesson)
      raise AssistantConversationAccessDeniedError, "Assistant access not allowed for this lesson"
    end

    # Find or create the conversation (this also updates updated_at for free lesson tracking)
    AssistantConversation::FindOrCreate.(user, lesson)

    # Generate the stateless conversation token
    generate_token
  end

  private
  def generate_token
    payload = {
      sub: user.id,
      lesson_slug: lesson.slug,
      exercise_slug: lesson.data[:slug],
      exp: 1.hour.from_now.to_i,
      iat: Time.current.to_i
    }

    JWT.encode(payload, Jiki.secrets.jwt_secret, 'HS256')
  end
end
