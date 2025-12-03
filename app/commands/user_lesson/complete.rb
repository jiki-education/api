class UserLesson::Complete
  include Mandate

  initialize_with :user, :lesson

  def call
    user_lesson.with_lock do
      # Guard: if already completed, return early (idempotent)
      return user_lesson if user_lesson.completed_at.present?

      # with_lock already provides transactional semantics, no need for nested transaction
      user_lesson.update!(completed_at: Time.current)

      user_level.update!(current_user_lesson: nil)

      # Unlock concept if this lesson unlocks one
      Concept::UnlockForUser.(lesson.unlocked_concept, user) if lesson.unlocked_concept

      # Unlock project if this lesson unlocks one
      UserProject::Create.(user, lesson.unlocked_project) if lesson.unlocked_project

      user_lesson
    end
  end

  memoize
  def user_lesson = UserLesson::Find.(user, lesson)

  memoize
  def user_level = UserLevel::Find.(user, lesson.level)
end
