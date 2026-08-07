class SerializeBadges
  include Mandate

  initialize_with :user

  def call
    visible_badges.map do |badge|
      acquired_badge = acquired_badges_by_badge_id[badge.id]
      state = determine_state(acquired_badge)

      SerializeBadge.(badge, state, acquired_badge:)
    end
  end

  private
  # Badges visible to the user:
  # - All non-secret badges (whether acquired or not)
  # - Secret badges that the user has acquired
  memoize
  def visible_badges
    Badge.where(secret: false).or(Badge.where(id: acquired_badge_ids)).
      order(:id)
  end

  memoize
  def acquired_badges_by_badge_id
    user.acquired_badges.
      includes(:badge).
      index_by(&:badge_id)
  end

  memoize
  def acquired_badge_ids
    user.acquired_badges.pluck(:badge_id)
  end

  def determine_state(acquired_badge)
    return 'locked' unless acquired_badge

    acquired_badge.revealed? ? 'revealed' : 'unrevealed'
  end
end
