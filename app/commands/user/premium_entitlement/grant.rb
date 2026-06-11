class User::PremiumEntitlement::Grant
  include Mandate

  initialize_with :user, :source, expires_at: nil, external_ref: nil

  def call
    became_premium = false

    user.with_lock do
      was_premium = user.premium?

      entitlement = user.premium_entitlements.active.find_by(source: source)
      if entitlement
        entitlement.update!(expires_at: expires_at, external_ref: external_ref) if changed?(entitlement)
      else
        user.premium_entitlements.create!(
          source: source,
          expires_at: expires_at,
          external_ref: external_ref,
          starts_at: Time.current
        )
      end

      became_premium = !was_premium && user.reload.premium?
    end

    User::UpgradeToPremium.(user, source: source) if became_premium
  end

  private
  def changed?(entitlement)
    entitlement.expires_at != expires_at || entitlement.external_ref != external_ref
  end
end
