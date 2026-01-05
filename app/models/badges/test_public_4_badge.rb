module Badges
  class TestPublic4Badge < Badge
    seed "Badge 2", "star", "Test badge 2"

    def award_to?(_user)
      true
    end
  end
end
