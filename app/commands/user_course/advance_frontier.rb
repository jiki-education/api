# Repoints a course's current level - but only ever forwards.
#
# The frontier is what the front-end derives the unlocked feature set from: for
# challenges it passes `current_level_slug` to the interpreter, which
# accumulates language features across every level up to (and including) that
# one. Yanking the frontier backwards therefore re-locks features the user has
# already earned - e.g. `push` reporting "not available at your current
# learning level" (forum t/2248) after a reopened earlier level pulled the
# pointer back.
#
# Moving backwards is never legitimate: a user working inside an earlier level
# - one reopened by a curriculum change, or a lesson they're revisiting - has
# still earned everything up to their furthest level.
class UserCourse::AdvanceFrontier
  include Mandate

  initialize_with :user_course, :user_level

  def call
    return if regression?

    user_course.update!(current_user_level: user_level)
  end

  private
  def regression?
    current = user_course.current_user_level
    return false unless current

    current.level.position > user_level.level.position
  end
end
