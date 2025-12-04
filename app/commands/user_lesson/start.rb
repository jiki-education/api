class UserLesson::Start
  include Mandate

  initialize_with :user, :lesson

  def call
    validate_can_start_lesson!

    ActiveRecord::Base.transaction do
      UserLesson.find_create_or_find_by!(user:, lesson:).tap do |user_lesson|
        # Only update tracking pointers on first creation
        if user_lesson.just_created?
          user_level.update!(current_user_lesson: user_lesson)
          user.update!(current_user_level: user_level)
        end
      end
    end
  end

  private
  memoize
  def user_level
    UserLevel::Find.(user, lesson.level)
  rescue ActiveRecord::RecordNotFound
    raise UserLevelNotFoundError, "Level not available"
  end

  def validate_can_start_lesson!
    # Check if there's a DIFFERENT lesson in progress on THIS level
    current_lesson = user_level.current_user_lesson
    if current_lesson.present? && current_lesson.completed_at.nil? && current_lesson.lesson_id != lesson.id
      raise LessonInProgressError, "Complete current lesson before starting a new one"
    end

    # Check if trying to start lesson in a different level
    current_level = user.current_user_level&.level
    return unless current_level && current_level.id != lesson.level_id
    return unless all_lessons_complete?(current_level)

    raise LevelNotCompletedError, "Complete the current level before starting lessons in the next level"
  end

  def all_lessons_complete?(level)
    completed_count = UserLesson.where(user: user, lesson: level.lessons).
      where.not(completed_at: nil).
      count
    completed_count == level.lessons.count
  end
end
