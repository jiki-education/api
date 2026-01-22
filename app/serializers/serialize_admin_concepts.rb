class SerializeAdminConcepts
  include Mandate

  initialize_with :concepts

  def call
    concepts.map do |concept|
      {
        id: concept.id,
        title: concept.title,
        slug: concept.slug,
        description: concept.description,
        standard_video_provider: concept.standard_video_provider,
        standard_video_id: concept.standard_video_id,
        premium_video_provider: concept.premium_video_provider,
        premium_video_id: concept.premium_video_id,
        children_count: concept.children_count
      }
    end
  end
end
