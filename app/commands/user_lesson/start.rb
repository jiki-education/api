class UserLesson::Start
  include Mandate

  initialize_with :user, :lesson

  def call
    # Short-circuit before validation: re-starting an existing UserLesson
    # (started or completed) is an idempotent no-op, regardless of where
    # the user currently is in the course.
    existing = UserLesson.find_by(user:, lesson:)
    return existing if existing

    validate_can_start_lesson!

    ActiveRecord::Base.transaction do
      UserLesson.find_create_or_find_by!(user:, lesson:) { |ul| ul.started_at = Time.current }.tap do |user_lesson|
        # Guard against a concurrent request winning the race in find_create_or_find_by!
        if user_lesson.just_created?
          user_level.update!(current_user_lesson: user_lesson)
          user_course.update!(current_user_level: user_level)
          track_first_ever_lesson_started!
        end
      end
    end
  end

  private
  memoize
  def course = lesson.level.course

  memoize
  def user_course
    user.user_courses.find_by!(course:)
  rescue ActiveRecord::RecordNotFound
    raise UserCourseNotFoundError, "Not enrolled in this course"
  end

  memoize
  def user_level
    UserLevel::Find.(user, lesson.level)
  rescue ActiveRecord::RecordNotFound
    raise UserLevelNotFoundError, "Level not available"
  end

  def validate_can_start_lesson!
    # Check if there's a DIFFERENT lesson in progress on THIS level
    current_lesson = user_level.current_user_lesson
    if current_lesson && current_lesson.completed_at.nil? && current_lesson.lesson_id != lesson.id
      raise LessonInProgressError, "Complete current lesson before starting a new one"
    end

    # Check if trying to start lesson in a different level
    current_level = user_course.current_user_level&.level
    return unless current_level && current_level.id != lesson.level_id
    return unless all_lessons_complete?(current_level)

    raise LevelNotCompletedError, "Complete the current level before starting lessons in the next level"
  end

  def all_lessons_complete?(level)
    completed_count = UserLesson.where(user:, lesson: level.lessons).
      where.not(completed_at: nil).
      count
    completed_count == level.lessons.count
  end

  def track_first_ever_lesson_started!
    return unless UserLesson.where(user:).count == 1

    Analytics::TrackEvent.defer(
      user,
      "first_lesson_started",
      properties: {
        lesson_id: lesson.id,
        lesson_slug: lesson.slug,
        level_id: lesson.level_id,
        level_slug: lesson.level.slug
      }
    )
  end
end
