class SerializeLesson
  include Mandate

  initialize_with :lesson, content: nil

  def call
    content_data = content || lesson.content_for_locale(I18n.locale)

    {
      slug: lesson.slug,
      title: content_data[:title],
      description: content_data[:description],
      type: lesson.type,
      data: lesson.data
    }
  end
end
