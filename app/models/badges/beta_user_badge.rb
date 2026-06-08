module Badges
  class BetaUserBadge < Badge
    CUTOFF = Time.utc(2026, 7, 1).freeze

    seed "Beta User", "Joined Jiki during the beta",
      fun_fact: "Beta users help shape the future of Jiki. Thank you for believing in us early!"

    def award_to?(user)
      user.created_at < CUTOFF
    end
  end
end
