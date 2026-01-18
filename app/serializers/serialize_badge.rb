class SerializeBadge
  include Mandate

  initialize_with :badge, :state, acquired_badge: nil

  def call
    {
      id: badge.id,
      name: badge.name,
      slug: badge.slug,
      description: badge.description,
      state:,
      num_awardees: badge.num_awardees
    }.tap do |hash|
      hash[:unlocked_at] = acquired_badge.created_at.iso8601 if acquired_badge
    end
  end
end
