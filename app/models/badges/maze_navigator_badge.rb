module Badges
  class MazeNavigatorBadge < Badge
    seed "Maze Navigator", "compass", "Completed the Solve a Maze lesson",
      fun_fact: "Maze-solving algorithms are used in robotics, game AI, and even GPS navigation!"

    def award_to?(user)
      user.user_lessons.completed.joins(:lesson).where(lessons: { slug: 'maze-solve-basic' }).exists?
    end
  end
end
