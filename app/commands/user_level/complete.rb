class UserLevel::Complete
  include Mandate

  initialize_with :user, :level

  def call
    user_level.with_lock do
      # Guard: if already completed, return early (idempotent)
      return user_level if user_level.completed_at.present?

      validate_all_lessons_complete!

      # with_lock already provides transactional semantics, no need for nested transaction
      user_level.update!(
        completed_at: Time.current,
        current_user_lesson: nil
      )

      create_next_user_level!

      # Send completion email asynchronously after transaction completes
      send_completion_email!(user_level)
    end

    user_level
  end

  memoize
  def user_level = UserLevel::Find.(user, level)

  private
  def validate_all_lessons_complete!
    total_lessons = level.lessons.count
    completed_lessons = UserLesson.where(user: user, lesson: level.lessons).
      where.not(completed_at: nil).count
    return if total_lessons == completed_lessons

    incomplete_count = total_lessons - completed_lessons
    raise LessonIncompleteError, "Cannot complete level: #{incomplete_count} lesson(s) incomplete"
  end

  def create_next_user_level!
    next_level = Level::FindNext.(level)
    return unless next_level

    UserLevel::Start.(user, next_level)
  end

  def send_completion_email!(user_level)
    User::SendEmail.(user_level) do
      UserLevelMailer.with(user_level:).completed(user_level).deliver_later
    end
  end
end
