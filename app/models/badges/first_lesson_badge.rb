module Badges
  class FirstLessonBadge < Badge
    seed "First Steps", "footprint", "Completed your first lesson",
      fun_fact: "The hardest part of any journey is taking the first step. You did it!"

    def award_to?(user)
      user.user_lessons.completed.exists?
    end
  end
end
