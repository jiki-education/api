class SerializeAdminConcept
  include Mandate

  initialize_with :concept

  def call
    {
      id: concept.id,
      title: concept.title,
      slug: concept.slug,
      description: concept.description,
      content_markdown: concept.content_markdown,
      video_data: concept.video_data,
      children_count: concept.children_count,
      lesson_ids: concept.lesson_ids,
      ancestors: serialize_ancestors
    }
  end

  private
  def serialize_ancestors
    concept.ancestors.map do |ancestor|
      {
        id: ancestor.id,
        title: ancestor.title,
        slug: ancestor.slug
      }
    end
  end
end
