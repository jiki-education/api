class SerializeConcepts
  include Mandate

  initialize_with :concepts, for_user: nil

  def call
    concepts.map do |concept|
      {
        title: concept.title,
        slug: concept.slug,
        description: concept.description,
        standard_video_provider: concept.standard_video_provider,
        standard_video_id: concept.standard_video_id,
        premium_video_provider: concept.premium_video_provider,
        premium_video_id: concept.premium_video_id,
        children_count: concept.children_count,
        user_may_access: user_may_access?(concept)
      }
    end
  end

  private
  def user_may_access?(concept)
    return true unless for_user

    unlocked_ids.include?(concept.id)
  end

  memoize
  def unlocked_ids = for_user&.unlocked_concept_ids || []
end
