module Badges
  class MemberBadge < Badge
    seed "Member", "logo", "Joined Jiki"

    def award_to?(_user)
      true
    end
  end
end
