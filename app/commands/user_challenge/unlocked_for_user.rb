class UserChallenge::UnlockedForUser
  include Mandate

  initialize_with :user, :challenge

  def call
    return true if challenge.unlocked_by_lesson_id.nil?

    UserLesson.
      where(user:, lesson_id: challenge.unlocked_by_lesson_id).
      where.not(completed_at: nil).
      exists?
  end
end
