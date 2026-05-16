module Badges
  class PremiumBadge < Badge
    seed "Premium", "Became a Premium member",
      fun_fact: "Thanks for supporting Jiki! Your premium membership helps us keep building."

    def award_to?(user)
      user.premium?
    end
  end
end
