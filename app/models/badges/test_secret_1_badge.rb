module Badges
  class TestSecret1Badge < Badge
    seed "Secret Badge", "lock", "Test secret badge", secret: true

    def award_to?(_user)
      true
    end
  end
end
