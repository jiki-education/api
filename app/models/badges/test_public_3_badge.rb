module Badges
  class TestPublic3Badge < Badge
    seed "Badge 1", "star", "Test badge 1"

    def award_to?(_user)
      true
    end
  end
end
