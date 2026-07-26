class UserLevel::Complete
  include Mandate

  initialize_with :user_level

  def call
    user_level.with_lock do
      # Guard: if already completed, return early (idempotent)
      return if user_level.completed_at.present?

      user_level.update!(
        completed_at: Time.current,
        current_user_lesson: nil
      )

      create_next_user_level!

      # Send completion email asynchronously after transaction completes
      send_completion_email!

      track_event!
    end
  end

  private
  delegate :user, :level, to: :user_level

  memoize
  def user_course = user.user_courses.find_by!(course: level.course)

  def create_next_user_level!
    next_level = Level::FindNext.(level)
    return unless next_level

    next_user_level = UserLevel::Start.(user, next_level)

    # UserLevel::Start only repoints the course's current level when it CREATES
    # the UserLevel. If the user was previously advanced onto next_level and
    # later pulled back (e.g. a curriculum change that reopened this level),
    # that UserLevel already exists, so the pointer would be stranded on the
    # now-completed level and every start on next_level would 422
    # (level_not_completed). Repoint explicitly so completion always advances.
    user_course.update!(current_user_level: next_user_level)
  end

  def send_completion_email!
    User::SendEmail.(user_level) do
      ProgressionMailer.level_completed(user_level).deliver_later
    end
  end

  def track_event!
    Analytics::TrackEvent.defer(
      user,
      "level_completed",
      properties: {
        level_id: level.id,
        level_slug: level.slug,
        position: UserLevel.where(user:).where.not(completed_at: nil).count
      }
    )
  end
end
