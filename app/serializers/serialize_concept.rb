class SerializeConcept
  include Mandate

  initialize_with :concept

  def call
    {
      title: concept.title,
      slug: concept.slug,
      description: concept.description,
      content_html: concept.content_html,
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
        title: ancestor.title,
        slug: ancestor.slug
      }
    end
  end
end
