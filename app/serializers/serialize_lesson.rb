class SerializeLesson
  include Mandate

  initialize_with :lesson, content: nil, include_data: true

  def call
    content_data = content || lesson.content_for_locale(I18n.locale)

    output = {
      slug: lesson.slug,
      title: content_data[:title],
      description: content_data[:description],
      type: lesson.type
    }
    output[:data] = lesson.data if include_data
    output
  end
end
