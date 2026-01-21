class SerializeAcquiredBadge
  include Mandate

  initialize_with :acquired_badge

  def call
    {
      id: acquired_badge.badge_id,
      name: badge_content[:name],
      slug: acquired_badge.slug,
      description: badge_content[:description],
      fun_fact: badge_content[:fun_fact],
      revealed: acquired_badge.revealed?,
      unlocked_at: acquired_badge.created_at.iso8601,
      num_awardees: acquired_badge.badge.num_awardees
    }
  end

  private
  def badge_content
    badge = acquired_badge.badge
    badge.content_for_locale(I18n.locale)
  end
end
