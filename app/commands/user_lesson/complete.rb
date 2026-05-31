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
      track_event!
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

    # Emit unlock event if this lesson unlocks a project. The project becomes
    # unlocked by virtue of this lesson being completed - no UserProject row is
    # created here (the row is created when the user actually starts it).
    emit_project_unlocked_event! if lesson.unlocked_project

    # Check for badges that might be awarded (badge's award_to? determines eligibility)
    AwardBadgeJob.perform_later(user, 'maze_navigator')
    AwardBadgeJob.perform_later(user, 'scenario_handler')
    AwardBadgeJob.perform_later(user, 'night_owl')

    # Log activity for streak tracking
    User::ActivityLog::LogActivity.(user, Date.current)
  end

  def emit_lesson_unlocked_event!
    return unless next_lesson

    Current.add_event(:lesson_unlocked, { lesson_slug: next_lesson.slug })
  end

  def emit_project_unlocked_event!
    Current.add_event(:project_unlocked, { project: SerializeProject.(lesson.unlocked_project) })
  end

  def track_event!
    properties = {
      lesson_id: lesson.id,
      lesson_slug: lesson.slug,
      level_id: level.id,
      level_slug: level.slug,
      position: UserLesson.where(user:).where.not(completed_at: nil).count
    }
    # started_at is nullable on the schema; defensively skip the duration
    # field rather than letting an arithmetic NoMethodError roll back the
    # whole completion transaction.
    properties[:seconds_since_lesson_started] = (Time.current - user_lesson.started_at).to_i if user_lesson.started_at

    Analytics::TrackEvent.defer(user, "lesson_completed", properties: properties)
  end

  memoize
  def next_lesson = level.lessons.where('position > ?', lesson.position).first

  memoize
  def user_lesson = UserLesson::Find.(user, lesson)

  memoize
  def user_level = UserLevel::Find.(user, level)
end
