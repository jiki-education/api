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
        video_data: concept.video_data,
        children_count: concept.children_count
      }
    end
  end
end
