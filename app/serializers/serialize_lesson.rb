class SerializeLesson
  include Mandate

  initialize_with :lesson, :user, content: nil, include_data: false

  def call
    raise "user is required when include_data is true" if include_data && user.nil?

    content_data = content || lesson.content_for_locale(I18n.locale)

    output = {
      slug: lesson.slug,
      title: content_data[:title],
      description: content_data[:description],
      type: lesson.type
    }
    output[:data] = data if include_data
    output
  end

  private
  def data
    d = lesson.data.dup
    d[:conversation_allowed] = AssistantConversation::CheckUserAccess.(user, lesson)

    return d unless d[:sources].present? && language.present?

    # Filter sources to only include:
    # - Sources matching the user's language, OR
    # - Sources with no language key (language-agnostic)
    d[:sources] = d[:sources].select do |source|
      source[:language].nil? || source[:language] == language
    end
    d
  end

  def language
    return nil unless user

    user_course = user.user_courses.find_by(course: lesson.level.course)
    user_course&.language
  end
end
