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
#
# Idempotent: if the lesson already exists (matched by uuid, falling back to
# slug) it is left exactly as it is - including its position - and only the user
# reconciliation runs. This means the command can be called from a migration
# even when the seeds have already created the lesson.
class Curriculum::AppendLesson
  include Mandate

  initialize_with :level, :lesson_attributes, reopen_completed: false

  def call
    ActiveRecord::Base.transaction do
      (existing_lesson || create_lesson!).tap do |lesson|
        reopen_for_completed_users!(lesson) if reopen_completed
      end
    end
  end

  private
  # Lesson#set_position assigns the next position at the end of the level.
  def create_lesson! = level.lessons.create!(**lesson_attributes)

  # Matched by uuid, falling back to slug, mirroring how the seeds sync lessons.
  memoize
  def existing_lesson
    uuid = lesson_attributes[:uuid]
    lesson = (Lesson.find_by(uuid:) if uuid.present?)
    lesson ||= Lesson.find_by(slug: lesson_attributes[:slug])
    return nil unless lesson

    # Appending is not a move: repositioning an existing lesson into a different
    # level is Curriculum::MoveLesson's job, and doing it here would reopen the
    # wrong level's users.
    raise "Lesson #{lesson.slug} already exists on level #{lesson.level.slug}" unless lesson.level == level

    lesson
  end

  def reopen_for_completed_users!(lesson)
    # Un-complete the level for everyone who had finished it, so the new lesson
    # resurfaces as their frontier. We deliberately do NOT touch
    # current_user_level: users whose frontier has moved past this level stay
    # put, and finishing the new lesson won't yank them backwards because
    # UserLevel::Complete only advances the frontier when completing the level
    # the user is currently on.
    #
    # Anyone who has already completed the new lesson is skipped: the seeds may
    # have created it before this ran, so they've already seen it and there's
    # nothing to resurface. Reopening their level would only push them back
    # through a lesson they've done.
    done_user_ids = UserLesson.where(lesson:).where.not(completed_at: nil).select(:user_id)

    UserLevel.where(level:).where.not(completed_at: nil).where.not(user_id: done_user_ids).find_each do |user_level|
      user_level.update!(completed_at: nil)
    end
  end
end
