class User::DowngradeToStandard
  include Mandate

  initialize_with :user

  def call
    user.with_lock do
      return if user.data.standard?

      user.data.update!(membership_type: 'standard')
    end

    send_downgrade_email!
    track_event!
  end

  private
  def send_downgrade_email!
    PremiumMailer.subscription_ended(user).deliver_later
  end

  def track_event!
    Analytics::TrackEvent.defer(user, "downgraded_to_standard")
  end
end
