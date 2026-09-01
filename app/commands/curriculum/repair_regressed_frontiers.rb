# Pushes the frontiers stranded by t/2248 back forwards.
#
# UserLesson::Start used to repoint current_user_level at whatever level the
# lesson being started belonged to. When `adventures-in-poetry` was appended to
# `advanced-loops` and that level was reopened, users whose real frontier was
# further on got dragged back to `advanced-loops` the moment they opened it -
# and then onto `arrays` when they completed it. The front-end derives the
# interpreter's unlocked feature set from the frontier, so those users lost
# language features they'd already earned.
#
# Deliberately scoped to those two levels rather than "any frontier behind the
# furthest UserLevel reached". That broader rule is NOT safe: MoveLesson
# backfills UserLevels ahead of a user's frontier, and the pull-back in
# 20260726120000 parks users behind theirs on purpose. Both would be trampled.
class Curriculum::RepairRegressedFrontiers
  include Mandate

  # Where a regressed frontier landed: `advanced-loops` (on starting the
  # appended lesson) or `arrays` (on completing it).
  REGRESSED_TO_SLUGS = %w[advanced-loops arrays].freeze

  def call
    UserCourse.joins(current_user_level: :level).
      where(levels: { slug: REGRESSED_TO_SLUGS }).
      includes(current_user_level: :level).
      find_each do |user_course|
        furthest = furthest_user_level(user_course)
        next unless furthest
        next unless furthest.level.position > user_course.current_user_level.level.position

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
