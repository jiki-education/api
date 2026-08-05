module Badges
  class FirstLessonBadge < Badge
    def award_to?(user)
      user.user_lessons.completed.exists?
    end
  end
end
