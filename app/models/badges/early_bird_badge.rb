module Badges
  class EarlyBirdBadge < Badge
    seed secret: true

    def award_to?(user)
      user.user_lessons.completed.pluck(:completed_at).any? do |completed_at|
        early_bird_time?(completed_at, user.timezone)
      end
    end

    private
    def early_bird_time?(time, timezone)
      hour = time.in_time_zone(timezone).hour
      hour >= 4 && hour < 9
    end
  end
end
