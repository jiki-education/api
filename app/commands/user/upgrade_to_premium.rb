class User::UpgradeToPremium
  include Mandate

  initialize_with :user, source: "stripe_checkout"

  # Fires the consequences of a user becoming premium. The caller is
  # responsible for detecting the 0→1 transition (e.g. via was_premium /
  # user.reload.premium?) — this command always runs its side effects.
  def call
    AwardBadgeJob.perform_later(user, "premium")
    User::SendWelcomeToPremiumEmail.(user)
    User::Identify.defer(user)
    Analytics::TrackEvent.defer(user, "upgraded_to_premium", properties: { source: source })
  end
end
