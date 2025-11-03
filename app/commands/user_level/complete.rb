class UserLevel::Complete
  include Mandate

  initialize_with :user, :level

  def call
    user_level.with_lock do
      # Guard: if already completed, return early (idempotent)
      return user_level if user_level.completed_at.present?

      # with_lock already provides transactional semantics, no need for nested transaction
      user_level.update!(completed_at: Time.current)
      create_next_user_level!

      # Send completion email asynchronously after transaction completes
      send_completion_email!(user_level)
    end

    user_level
  end

  memoize
  def user_level = UserLevel::FindOrCreate.(user, level)

  private
  def create_next_user_level!
    next_level = Level::FindNext.(level)
    return unless next_level

    UserLevel::FindOrCreate.(user, next_level)
  end

  def send_completion_email!(user_level)
    User::SendEmail.(user_level) do
      UserLevelMailer.with(user_level:).completed(user_level).deliver_later
    end
  end
end
