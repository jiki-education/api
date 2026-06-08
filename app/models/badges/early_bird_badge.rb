module Badges
  class EarlyBirdBadge < Badge
    seed "Early Bird", "Completed a lesson in the early-morning hours",
      fun_fact: "The early bird catches the worm. Coding before the world wakes up is a superpower!",
      secret: true

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
