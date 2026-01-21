module Badges
  class LevelCompletionistBadge < Badge
    seed "Level Completionist", "trophy", "Completed an entire level",
      fun_fact: "Completing a full level shows real dedication. You're building strong foundations!"

    def award_to?(user)
      user.user_levels.any? do |user_level|
        level = user_level.level
        completed_lessons = user.user_lessons.completed.joins(:lesson).where(lessons: { level: level }).count
        completed_lessons >= level.lessons.count
      end
    end
  end
end
