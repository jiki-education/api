class SerializeConcepts
  include Mandate

  initialize_with :concepts, for_user: nil

  def call
    concepts.map do |concept|
      {
        title: concept.title,
        slug: concept.slug,
        description: concept.description,
        video_data: concept.video_data,
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
