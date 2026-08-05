module Badges
  class BetaUserBadge < Badge
    CUTOFF = Time.utc(2026, 7, 1).freeze
    seed secret: true

    def award_to?(user)
      user.created_at < CUTOFF
    end
  end
end
