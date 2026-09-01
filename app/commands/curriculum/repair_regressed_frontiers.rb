# Pushes stranded course frontiers back forwards.
#
# UserLesson::Start used to repoint current_user_level at whatever level the
# lesson being started belonged to. When `adventures-in-poetry` was appended to
# `advanced-loops` and that level was reopened, users whose real frontier was
# far ahead got dragged back to `advanced-loops` the moment they opened it -
# and, on completing it, onto `arrays` rather than back to where they were.
# The front-end derives the interpreter's unlocked feature set from the
# frontier, so those users lost language features they'd already earned
# (forum t/2248).
#
# A frontier behind the furthest level a user has actually reached is never
# legitimate - UserLevels are only ever created going forwards - so this
# repoints every such course at that furthest level. It is idempotent.
class Curriculum::RepairRegressedFrontiers
  include Mandate

  def call
    UserCourse.includes(current_user_level: :level).find_each do |user_course|
      current = user_course.current_user_level
      next unless current

      furthest = furthest_user_level(user_course)
      next unless furthest
      next unless furthest.level.position > current.level.position

      user_course.update!(current_user_level: furthest)
    end
  end

  private
  def furthest_user_level(user_course)
    UserLevel.joins(:level).
      where(user_id: user_course.user_id, levels: { course_id: user_course.course_id }).
      order("levels.position DESC").
      first
  end
end
