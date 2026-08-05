module Badges
  class TownsfolkBadge < Badge
    # Awarded when a user completes Discourse SSO, so eligibility is implied by
    # the enqueue site (Auth::DiscourseController#sso).
    def award_to?(_user) = true
  end
end
