module Badges
  class MemberBadge < Badge
    seed "Member", "logo", "Joined Jiki",
      fun_fact: "Welcome to the community! Every expert was once a beginner."

    def award_to?(_user)
      true
    end
  end
end
