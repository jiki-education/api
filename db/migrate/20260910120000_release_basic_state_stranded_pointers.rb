# Unsticks the users left with no way forward in `basic-state` when #707 swapped
# `finish-wall` ahead of `golf-rolling-ball-state`.
#
# Anyone parked on golf with finish-wall outstanding has been offered finish-wall
# by the front-end ever since, while UserLesson::Start refused to open it
# (LessonInProgressError) - 18 users at the time of writing. Releasing the
# pointer sends them to finish-wall and keeps their golf submissions for when
# they come back to it.
class ReleaseBasicStateStrandedPointers < ActiveRecord::Migration[8.1]
  def up
    level = Level.find_by(slug: 'basic-state')
    return unless level

    Curriculum::ReleaseStrandedLessonPointers.(level)
  end

  def down
    # The stranded pointers were a dead end; there is nothing worth restoring.
  end
end
