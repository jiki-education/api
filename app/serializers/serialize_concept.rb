class SerializeConcept
  include Mandate

  initialize_with :concept

  def call
    {
      title: concept.title,
      slug: concept.slug,
      description: concept.description,
      video_data: concept.unlocked_by_lesson&.data&.[](:sources)
    }
  end
end
