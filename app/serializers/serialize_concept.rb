class SerializeConcept
  include Mandate

  initialize_with :concept

  def call
    {
      title: concept.title,
      slug: concept.slug,
      description: concept.description,
      content_html: concept.content_html,
      video_data: concept.unlocked_by_lesson&.data&.[](:sources),
      children_count: concept.children_count,
      ancestors: serialize_ancestors
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
end
