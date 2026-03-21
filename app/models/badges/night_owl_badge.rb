module Badges
  class NightOwlBadge < Badge
    seed "Night Owl", "owl", "Completed a lesson in the wee hours",
      fun_fact: "Jeremy grew up coding late into the night." \
                "There's something magical about coding when the world is asleep!",
      secret: true

    def award_to?(user)
      user.user_lessons.completed.any? do |ul|
        night_owl_time?(ul.completed_at, user.timezone)
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
