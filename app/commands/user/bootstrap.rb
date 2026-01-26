class User::Bootstrap
  include Mandate

  initialize_with :user

  def call
    User::SendWelcomeEmail.defer(user)
    setup_course!
    AwardBadgeJob.perform_later(user, 'member')
  end

  private
  def setup_course!
    UserCourse::Enroll.(user, course)
    first_level = course.levels.first
    UserLevel::Start.(user, first_level) if first_level
  end

  memoize
  def course = Course.find_by!(slug: "coding-fundamentals")
end
