module Badges
  class EarlyBirdBadge < Badge
    seed "Early Bird", "sunrise", "Joined during early access",
      fun_fact: "Early adopters help shape the future of products. Thank you for believing in us!",
      secret: true

    def award_to?(user)
      user.created_at < 1.month.ago
    end
  end
end
