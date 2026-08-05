module Badges
  class NightOwlBadge < Badge
    seed secret: true

    def award_to?(user)
      user.user_lessons.completed.pluck(:completed_at).any? do |completed_at|
        night_owl_time?(completed_at, user.timezone)
      end
    end

    private
    def night_owl_time?(time, timezone)
      local = time.in_time_zone(timezone)
      hour = local.hour
      min = local.min

      hour >= 21 || hour < 2 || (hour == 2 && min <= 30)
    end
  end
end
