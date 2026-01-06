class User::Bootstrap
  include Mandate

  initialize_with :user

  def call
    # Queue welcome email to be sent asynchronously
    User::SendWelcomeEmail.defer(user)

    # Create user_level for first level
    first_level = Level.order(:position).first
    UserLevel::Start.(user, first_level) if first_level

    # Award member badge
    AwardBadgeJob.perform_later(user, 'member')
  end
end
