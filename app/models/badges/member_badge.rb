module Badges
  class MemberBadge < Badge
    def award_to?(_user)
      true
    end
  end
end
