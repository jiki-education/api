class SerializeAdminConcepts
  include Mandate

  initialize_with :concepts

  def call
    concepts.map do |concept|
      {
        id: concept.id,
        slug: concept.slug,
        video_data: concept.unlocked_by_lesson&.data&.[](:sources)
      }
    end
  end
end
