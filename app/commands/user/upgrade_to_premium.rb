class User::UpgradeToPremium
  include Mandate

  initialize_with :user, source: "stripe_checkout"

  def call
    user.with_lock do
      return if user.data.premium?

      user.data.update!(membership_type: 'premium')
    end

    award_badge!
    User::SendWelcomeToPremiumEmail.(user)
    User::Identify.defer(user)
    track_event!
  end

  private
  def award_badge!
    AwardBadgeJob.perform_later(user, 'premium')
  end

  def track_event!
    Analytics::TrackEvent.defer(user, "upgraded_to_premium", properties: { source: source })
  end
end
