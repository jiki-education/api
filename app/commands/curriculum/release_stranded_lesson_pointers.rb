# Clears level pointers that a lesson reorder left sitting behind the frontier.
#
# UserLevel#current_user_lesson is the lesson a user is part-way through, and
# UserLesson::Start refuses to start a different lesson on the level while it is
# incomplete (LessonInProgressError). Reordering the level's lessons can move
# that lesson BEHIND one the user hasn't done: the front-end then advertises the
# newly-earlier lesson as their next, starting it raises, and the lesson they
# were parked on is no longer advertised - there is no way forward from the UI.
#
# That is what a straight swap of two lessons in `basic-state` did to 18 users
# (finish-wall moved ahead of golf-rolling-ball-state, PR #707).
#
# Releasing the pointer is enough: the UserLesson row and its submissions are
# left untouched, so the user does the now-earlier lesson first and, on
# returning to the one they were parked on, UserLesson::Start short-circuits
# onto their existing row with their work intact.
class Curriculum::ReleaseStrandedLessonPointers
  include Mandate

  initialize_with :level

  def call
    stranded_user_levels.each { |user_level| user_level.update!(current_user_lesson: nil) }
  end

  private
  memoize
  def stranded_user_levels
    candidates.select { |user_level| stranded?(user_level) }
  end

  memoize
  def candidates
    UserLevel.where(level:).where.not(current_user_lesson_id: nil).
      includes(current_user_lesson: :lesson).
      to_a
  end

  def stranded?(user_level)
    current_lesson = user_level.current_user_lesson

    # A completed pointer blocks nothing - UserLesson::Start only refuses while
    # the lesson in progress is incomplete.
    return false if current_lesson.completed_at.present?

    earlier_lesson_ids(current_lesson.lesson).any? do |lesson_id|
      completed_lesson_ids[user_level.user_id].exclude?(lesson_id)
    end
  end

  # Mirrors UserLesson::Start#earlier_lessons_complete?, which is the guard that
  # turns a demoted pointer into a dead end.
  def earlier_lesson_ids(lesson)
    lesson_positions.select { |_id, position| position < lesson.position }.keys
  end

  memoize
  def lesson_positions = level.lessons.pluck(:id, :position).to_h

  # Loaded in one go: doing it per user level is an N+1 over the whole level.
  memoize
  def completed_lesson_ids
    completed = UserLesson.completed.
      where(user_id: candidates.map(&:user_id), lesson_id: lesson_positions.keys).
      pluck(:user_id, :lesson_id).
      group_by(&:first).
      transform_values { |rows| rows.map(&:last) }

    completed.default = [].freeze
    completed
  end
end
