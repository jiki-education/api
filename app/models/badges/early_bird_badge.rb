module Badges
  class EarlyBirdBadge < Badge
    seed "Early Bird", "sunrise", "Joined during early access", secret: true

    def award_to?(user)
      user.created_at < 1.month.ago
    end
  end
end
