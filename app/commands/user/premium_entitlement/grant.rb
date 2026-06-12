class User::PremiumEntitlement::Grant
  include Mandate

  initialize_with :user, :source, expires_at: nil

  def call
    became_premium = false

    user.with_lock do
      was_premium = user.premium?

      entitlement = user.premium_entitlements.active.find_by(source: source)
      if entitlement
        entitlement.update!(expires_at: expires_at) if entitlement.expires_at != expires_at
      else
        user.premium_entitlements.create!(source: source, expires_at: expires_at)
      end

      became_premium = !was_premium && user.reload.premium?
    end

    User::UpgradeToPremium.(user, source: source) if became_premium
  end
end
