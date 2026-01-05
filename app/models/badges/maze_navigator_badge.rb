module Badges
  class MazeNavigatorBadge < Badge
    seed "Maze Navigator", "compass", "Completed the Solve a Maze lesson"

    def award_to?(user)
      user.user_lessons.completed.joins(:lesson).where(lessons: { slug: 'maze-solve-basic' }).exists?
    end
  end
end
