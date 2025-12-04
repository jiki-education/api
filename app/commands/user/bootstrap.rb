class User::Bootstrap
  include Mandate

  initialize_with :user

  def call
    # Queue welcome email to be sent asynchronously
    User::SendWelcomeEmail.defer(user)

    # Create user_level for first level
    first_level = Level.order(:position).first
    UserLevel::Start.(user, first_level) if first_level

    # Future: Add other bootstrap operations here as needed:
    # - Award badges
    # - Create auth tokens
    # - Track metrics
  end
end
