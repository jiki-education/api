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
      standard_video_provider: concept.standard_video_provider,
      standard_video_id: concept.standard_video_id,
      premium_video_provider: concept.premium_video_provider,
      premium_video_id: concept.premium_video_id,
      children_count: concept.children_count,
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
