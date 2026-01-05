module Badges
  class TestPublic2Badge < Badge
    seed "Public Badge 2", "star", "Test public badge 2"

    def award_to?(_user)
      true
    end
  end
end
