module Badges
  class TestSecretBadge < Badge
    seed "Secret Badge", "lock", "Test secret badge",
      fun_fact: "You found a secret! Hidden achievements add mystery to the learning journey.",
      secret: true

    def award_to?(_user)
      true
    end
  end
end
