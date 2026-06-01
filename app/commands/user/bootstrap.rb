class User::Bootstrap
  include Mandate

  initialize_with :user, :provider, attribution: nil

  def call
    send_welcome_email!
    enroll_in_course!
    award_member_badge!
    attribute!
    track!
  end

  private
  def send_welcome_email!
    AccountMailer.welcome(user).deliver_later
  end

  def enroll_in_course!
    UserCourse::Enroll.(user, course)
  end

  def award_member_badge!
    AwardBadgeJob.perform_later(user, 'member')
  end

  def attribute!
    return if attribution.blank?

    user.data.update!(signup_attribution: attribution)
  end

  def track!
    User::Identify.defer(user)
    Analytics::TrackEvent.defer(
      user,
      "user_signed_up",
      properties: { provider: }.merge(attribution || {})
    )
  end

  memoize
  def course = Course.find_by!(slug: "coding-fundamentals")
end
