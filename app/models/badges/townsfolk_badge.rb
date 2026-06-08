module Badges
  class TownsfolkBadge < Badge
    seed "Townsfolk", "Joined the Jiki community forum",
      fun_fact: "The best way to learn is to teach. Welcome to the conversation!"

    # Awarded when a user completes Discourse SSO, so eligibility is implied by
    # the enqueue site (Auth::DiscourseController#sso).
    def award_to?(_user) = true
  end
end
