class UserProject::UnlockedForUser
  include Mandate

  initialize_with :user, :project

  def call
    return true if project.unlocked_by_lesson_id.nil?

    UserLesson.
      where(user:, lesson_id: project.unlocked_by_lesson_id).
      where.not(completed_at: nil).
      exists?
  end
end
