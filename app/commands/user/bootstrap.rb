class User::Bootstrap
  include Mandate

  initialize_with :user, course: nil

  def call
    # Queue welcome email to be sent asynchronously
    User::SendWelcomeEmail.defer(user)

    # If a course is provided, enroll the user and start them on the first level
    if course
      UserCourse::Enroll.(user, course)
      first_level = course.levels.first
      UserLevel::Start.(user, first_level) if first_level
    end

    # Award member badge
    AwardBadgeJob.perform_later(user, 'member')
  end
end
