class User::UpgradeToPremium
  include Mandate

  initialize_with :user, source: "stripe_checkout"

  def call
    user.with_lock do
      return if user.data.premium?

      user.data.update!(membership_type: 'premium')
    end

    award_badge!
    send_welcome_email!
    track_event!
  end

  private
  def award_badge!
    AwardBadgeJob.perform_later(user, 'premium')
  end

  def send_welcome_email!
    PremiumMailer.welcome_to_premium(user).deliver_later
  end

  def track_event!
    Analytics::TrackEvent.defer(
      user,
      "upgraded_to_premium",
      properties: {
        source: source,
        days_since_signup: (Date.current - user.created_at.to_date).to_i
      }
    )
  end
end
