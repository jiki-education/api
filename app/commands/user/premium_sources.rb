class User::PremiumSources
  include Mandate

  initialize_with :user

  def call
    sources = []
    sources << PremiumEntitlement::STRIPE if user.data.stripe_active?
    sources.concat(user.premium_entitlements.active.pluck(:source))
    sources
  end
end
