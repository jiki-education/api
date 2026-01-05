module Badges
  class TestPublic1Badge < Badge
    seed "Public Badge 1", "star", "Test public badge 1"

    def award_to?(_user)
      true
    end
  end
end
