class User::DowngradeToStandard
  include Mandate

  initialize_with :user

  # Fires the consequences of a user losing premium. The caller is
  # responsible for detecting the 1→0 transition (e.g. via was_premium /
  # !user.reload.premium?) — this command always runs its side effects.
  def call
    PremiumMailer.subscription_ended(user).deliver_later
    User::Identify.defer(user)
    Analytics::TrackEvent.defer(user, "downgraded_to_standard")
  end
end
