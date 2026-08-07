module Badges
  class PremiumBadge < Badge
    def award_to?(user)
      user.premium?
    end
  end
end
