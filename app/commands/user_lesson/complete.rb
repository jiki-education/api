class UserLesson::Complete
  include Mandate

  initialize_with :user, :lesson

  def call
    user_lesson.with_lock do
      # Guard: if already completed, return early (idempotent)
      return if user_lesson.completed_at.present?

      # Mark lesson as complete
      user_lesson.update!(completed_at: Time.current)

      # Update current level so it's ready for the next lesson
      user_level.update!(current_user_lesson: nil)

      unlock_next_thing!
      handle_side_effects!
    end
  end

  private
  delegate :level, to: :lesson

  def unlock_next_thing!
    if next_lesson
      emit_lesson_unlocked_event!
    else
      UserLevel::Complete.(user_level)
    end
  end

  def handle_side_effects!
    # Unlock concept if this lesson unlocks one
    Concept::UnlockForUser.(lesson.unlocked_concept, user) if lesson.unlocked_concept

    # Unlock project if this lesson unlocks one
    UserProject::Create.(user, lesson.unlocked_project) if lesson.unlocked_project

    # Check for badges that might be awarded (badge's award_to? determines eligibility)
    AwardBadgeJob.perform_later(user, 'maze_navigator')

    # Log activity for streak tracking
    User::ActivityLog::LogActivity.(user, Date.current)
  end

  def emit_lesson_unlocked_event!
    return unless next_lesson

    Current.add_event(:lesson_unlocked, { lesson_slug: next_lesson.slug })
  end

  memoize
  def next_lesson = level.lessons.where('position > ?', lesson.position).first

  memoize
  def user_lesson = UserLesson::Find.(user, lesson)

  memoize
  def user_level = UserLevel::Find.(user, level)
end
