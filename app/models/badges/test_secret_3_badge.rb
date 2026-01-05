module Badges
  class TestSecret3Badge < Badge
    seed "Secret Badge 2", "lock", "Test secret badge 2", secret: true

    def award_to?(_user)
      true
    end
  end
end
