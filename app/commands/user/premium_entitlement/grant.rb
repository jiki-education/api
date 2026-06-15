class User::PremiumEntitlement::Grant
  include Mandate

  initialize_with :user, :source, expires_at: nil

  def call
    if entitlement
      entitlement.update!(expires_at: expires_at) if entitlement.expires_at != expires_at
    else
      user.premium_entitlements.create!(source: source, expires_at: expires_at)
    end

    # Idempotent — short-circuits if the user is already premium.
    User::UpgradeToPremium.(user, source: source)
  end

  private
  memoize
  def entitlement = user.premium_entitlements.active.find_by(source: source)
end
