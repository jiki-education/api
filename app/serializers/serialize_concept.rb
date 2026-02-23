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
    concept.lessons.map do |lesson|
      SerializeLesson.(lesson, nil)
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
