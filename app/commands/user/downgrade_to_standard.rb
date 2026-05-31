class User::DowngradeToStandard
  include Mandate

  initialize_with :user

  def call
    user.with_lock do
      return if user.data.standard?

      user.data.update!(membership_type: 'standard')
    end

    PremiumMailer.subscription_ended(user).deliver_later
    User::Identify.defer(user)
    Analytics::TrackEvent.defer(user, "downgraded_to_standard")
  end
end
