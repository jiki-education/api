# Safely add a lesson to a level, reconciling existing users.
#
# ALWAYS appends at the end of the level: inserting mid-level would retroactively
# change which lessons count as "earlier" for the position-based ordering guard
# in UserLesson::Start, scrambling in-flight users. Call this from a migration
# rather than hand-rolling the user reconciliation.
#
# Users still working through (or yet to reach) the level need no reconciliation
# - the new lesson slots into their ordering naturally. The only affected group
# is users who had ALREADY completed the level: SerializeUserLevels never
# advertises a next lesson on a completed level, so the new lesson is invisible
# to them. Pass reopen_completed: true to resurface it (see below).
class Curriculum::AppendLesson
  include Mandate

  initialize_with :level, :lesson_attributes, reopen_completed: false

  def call
    ActiveRecord::Base.transaction do
      create_lesson!.tap do
        reopen_for_completed_users! if reopen_completed
      end
    end
  end

  private
  # Lesson#set_position assigns the next position at the end of the level.
  def create_lesson! = level.lessons.create!(**lesson_attributes)

  def reopen_for_completed_users!
    # Un-complete the level for everyone who had finished it, so the new lesson
    # resurfaces as their frontier. We deliberately do NOT touch
    # current_user_level: users whose frontier has moved past this level stay
    # put, and finishing the new lesson won't yank them backwards because
    # UserLevel::Complete only advances the frontier when completing the level
    # the user is currently on.
    UserLevel.where(level:).where.not(completed_at: nil).find_each do |user_level|
      user_level.update!(completed_at: nil)
    end
  end
end
