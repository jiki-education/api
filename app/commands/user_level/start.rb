class UserLevel::Start
  include Mandate

  initialize_with :user, :level

  def call
    ActiveRecord::Base.transaction do
      UserLevel.find_create_or_find_by!(user:, level:).tap do |user_level|
        if user_level.just_created?
          user_course.update!(current_user_level: user_level)
          emit_first_lesson_unlocked_event!
        end
      end
    end
  end

  private
  delegate :course, to: :level

  memoize
  def user_course
    user.user_courses.find_by!(course:)
  end

  def emit_first_lesson_unlocked_event!
    first_lesson = level.lessons.first
    return unless first_lesson

    Current.add_event(:lesson_unlocked, { lesson_slug: first_lesson.slug })
  end
end
