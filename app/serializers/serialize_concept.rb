class SerializeConcept
  include Mandate

  initialize_with :concept

  def call
    {
      title: concept.title,
      slug: concept.slug,
      description: concept.description,
      content_html: concept.content_html,
      video_data: concept.video_data,
      children_count: concept.children_count,
      ancestors: serialize_ancestors,
      related_lessons: serialize_related_lessons,
      related_concepts: serialize_related_concepts
    }
  end

  private
  def serialize_ancestors
    concept.ancestors.map do |ancestor|
      {
        title: ancestor.title,
        slug: ancestor.slug
      }
    end
  end

  def serialize_related_lessons
    lessons = concept.lessons.to_a
    return [] if lessons.empty?

    locale = I18n.locale
    translations = if locale.to_s != 'en'
                     Lesson::Translation.where(lesson_id: lessons.map(&:id), locale: locale).index_by(&:lesson_id)
                   end

    lessons.map do |lesson|
      model = translations ? (translations[lesson.id] || lesson) : lesson
      content = Lesson.translatable_fields.index_with { |field| model.public_send(field) }
      SerializeLesson.(lesson, nil, content: content)
    end
  end

  def serialize_related_concepts
    concept.related_concepts.map do |related|
      {
        title: related.title,
        slug: related.slug,
        description: related.description
      }
    end
  end
end
