module Badges
  class TestSecret2Badge < Badge
    seed "Secret Badge 1", "lock", "Test secret badge 1", secret: true

    def award_to?(_user)
      true
    end
  end
end
