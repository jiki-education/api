module Badges
  class MazeNavigatorBadge < Badge
    def award_to?(user)
      user.user_lessons.completed.joins(:lesson).where(lessons: { slug: 'maze-solve-basic' }).exists?
    end
  end
end
