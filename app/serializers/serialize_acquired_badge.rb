class SerializeAcquiredBadge
  include Mandate

  initialize_with :acquired_badge

  def call
    {
      id: acquired_badge.badge_id,
      name: acquired_badge.name,
      slug: acquired_badge.slug,
      description: acquired_badge.description,
      revealed: acquired_badge.revealed?,
      unlocked_at: acquired_badge.created_at.iso8601,
      num_awardees: acquired_badge.badge.num_awardees
    }
  end
end
