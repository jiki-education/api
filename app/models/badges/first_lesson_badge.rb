module Badges
  class FirstLessonBadge < Badge
    seed "First Steps", "footprint", "Completed your first lesson"

    def award_to?(user)
      user.user_lessons.completed.exists?
    end
  end
end
