# A high-water mark, like completed_at: once set it is never cleared or moved.
# The bonus can be passed at completion time (via UserLesson::Complete) or
# later, when a user comes back to an already-completed lesson to finish it off.
class UserLesson::CompleteBonus
  include Mandate

  initialize_with :user, :lesson

  def call
    return if user_lesson.bonus_completed_at.present?

    user_lesson.update!(bonus_completed_at: Time.current)
    track_event!
  end

  private
  memoize
  def user_lesson
    UserLesson::Find.(user, lesson)
  rescue ActiveRecord::RecordNotFound
    raise UserLessonNotFoundError
  end

  def track_event!
    Analytics::TrackEvent.defer(
      user,
      "lesson_bonus_completed",
      properties: {
        lesson_id: lesson.id,
        lesson_slug: lesson.slug,
        level_id: lesson.level_id,
        level_slug: lesson.level.slug
      }
    )
  end
end
