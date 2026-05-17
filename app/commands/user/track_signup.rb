class User::TrackSignup
  include Mandate

  initialize_with :user, :provider, attribution: nil

  def call
    user.data.update!(signup_attribution: attribution) if attribution.present?

    Analytics::TrackEvent.defer(
      user,
      "user_signed_up",
      properties: { provider: }.merge(attribution || {})
    )
  end
end
