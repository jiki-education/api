class AssistantConversation::CreateConversationToken
  include Mandate

  initialize_with :user, :context

  def call
    unless AssistantConversation::CheckUserAccess.(user, context)
      raise AssistantConversationAccessDeniedError, "Assistant access not allowed for this #{context_kind}"
    end

    # Find or create the conversation (this also updates updated_at for free lesson tracking)
    AssistantConversation::FindOrCreate.(user, context)

    # Generate the stateless conversation token
    generate_token
  end

  private
  def generate_token
    payload = {
      sub: user.id,
      exercise_slug: exercise_slug,
      exp: 1.hour.from_now.to_i,
      iat: Time.current.to_i
    }
    payload["#{context_kind}_slug"] = context.slug

    JWT.encode(payload, Jiki.secrets.jwt_secret, 'HS256')
  end

  def context_kind
    case context
    when Lesson then 'lesson'
    when Challenge then 'challenge'
    end
  end

  def exercise_slug
    case context
    when Lesson then context.data[:slug]
    when Challenge then context.exercise_slug
    end
  end
end
