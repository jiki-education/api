# Safely move a lesson from one level to another, reconciling existing users.
#
# ALWAYS appends at the end of the destination level (see Curriculum::AppendLesson
# for why mid-level inserts are unsafe). The Lesson row keeps its id, so users'
# UserLesson records travel with it. Call this from a migration rather than
# hand-rolling the reconciliation - there are three user populations to fix up,
# and missing any of them wedges people (this is the class of bug behind the
# pangram move, Sentry JIKI-API-X):
#
#   1. Users on the SOURCE level whose only-remaining lesson was the one moving
#      away are now silently "all done" on that level, but nothing marked the
#      level complete or advanced them - so their next start 422s. We complete
#      the source level for them (which advances the frontier correctly).
#   2. Users who progressed on the lesson while it lived on the source level
#      hold a UserLesson but may have no UserLevel for the DESTINATION, so
#      SerializeUserLevels (which joins user_levels -> lessons) can't show their
#      progress. We backfill an incomplete UserLevel.
#   3. Users who had already completed the DESTINATION level can't see the newly
#      arrived lesson (completed levels never advertise a next lesson). Pass
#      reopen_completed: true to resurface it for them.
#
# No current_user_level pointer is ever moved backwards.
class Curriculum::MoveLesson
  include Mandate

  initialize_with :lesson, :to_level, reopen_completed: false

  def call
    ActiveRecord::Base.transaction do
      move_lesson!
      complete_source_level_where_now_finished!
      backfill_destination_user_levels!
      reopen_destination_for_completed_users! if reopen_completed
    end
  end

  private
  memoize
  def source_level = lesson.level

  def move_lesson!
    # Capture the source before reassigning; append at the end of the destination.
    source_level
    next_position = (to_level.lessons.where.not(id: lesson.id).maximum(:position) || 0) + 1
    lesson.update!(level: to_level, position: next_position)
  end

  def complete_source_level_where_now_finished!
    remaining_lesson_ids = source_level.lessons.where.not(id: lesson.id).pluck(:id)

    # An empty source level can't be "complete" in any meaningful way - leave it.
    return if remaining_lesson_ids.empty?

    UserLevel.where(level: source_level, completed_at: nil).find_each do |user_level|
      completed_count = UserLesson.where(user_id: user_level.user_id, lesson_id: remaining_lesson_ids).
        where.not(completed_at: nil).count

      next unless completed_count == remaining_lesson_ids.count

      # Every remaining source lesson is done, so the level is legitimately
      # finished now. UserLevel::Complete marks it complete, clears the (possibly
      # dangling) current_user_lesson, and advances the frontier if this is the
      # user's current level.
      UserLevel::Complete.(user_level)
    end
  end

  def backfill_destination_user_levels!
    UserLesson.where(lesson:).distinct.pluck(:user_id).each do |user_id|
      next if UserLevel.exists?(user_id:, level: to_level)

      UserLevel.create!(user_id:, level: to_level)
    end
  end

  def reopen_destination_for_completed_users!
    UserLevel.where(level: to_level).where.not(completed_at: nil).find_each do |user_level|
      user_level.update!(completed_at: nil)
    end
  end
end
