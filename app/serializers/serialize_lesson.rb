class SerializeLesson
  include Mandate

  initialize_with :lesson, :user, content: nil, include_data: false

  def call
    content_data = content || lesson.content_for_locale(I18n.locale)

    output = {
      slug: lesson.slug,
      title: content_data[:title],
      description: content_data[:description],
      type: lesson.type
    }
    output[:data] = filtered_data if include_data
    output
  end

  private
  def filtered_data
    data = lesson.data.dup
    return data unless data[:sources].present? && language.present?

    # Filter sources to only include:
    # - Sources matching the user's language, OR
    # - Sources with no language key (language-agnostic)
    data[:sources] = data[:sources].select do |source|
      source[:language].nil? || source[:language] == language
    end
    data
  end

  def language
    return nil unless user

    user_course = user.user_courses.find_by(course: lesson.level.course)
    user_course&.language
  end
end
