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
    end
  end

  private
  delegate :user, :level, to: :user_level

  def create_next_user_level!
    next_level = Level::FindNext.(level)
    return unless next_level

    UserLevel::Start.(user, next_level)
  end

  def send_completion_email!
    User::SendEmail.(user_level) do
      ProgressionMailer.level_completed(user_level).deliver_later
    end
  end
end
