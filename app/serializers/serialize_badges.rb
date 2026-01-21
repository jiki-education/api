class SerializeBadges
  include Mandate

  initialize_with :user

  def call
    visible_badges.map do |badge|
      acquired_badge = acquired_badges_by_badge_id[badge.id]
      state = determine_state(acquired_badge)

      SerializeBadge.(badge, state, acquired_badge:, content: badge_contents[badge.id])
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

  # N+1 avoidance: preload all badge content for the current locale
  memoize
  def badge_contents
    # Build English content hash (used directly for :en, or as fallback)
    english_content = visible_badges.to_h do |b|
      [b.id, { name: b.name, description: b.description, fun_fact: b.fun_fact }]
    end

    return english_content if I18n.locale.to_s == "en"

    # Get translations, merge with English fallback
    translated = Badge::Translation.where(locale: I18n.locale, badge: visible_badges).
      pluck(:badge_id, :name, :description, :fun_fact).
      to_h { |id, name, desc, fun_fact| [id, { name: name, description: desc, fun_fact: fun_fact }] }

    english_content.merge(translated)
  end
end
