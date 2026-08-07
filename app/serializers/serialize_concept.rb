class SerializeConcept
  include Mandate

  initialize_with :concept

  def call
    {
      slug: concept.slug,
      video_data: concept.unlocked_by_lesson&.data&.[](:sources)
    }
  end
end
