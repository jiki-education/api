class User::PremiumEntitlement::Revoke
  include Mandate

  initialize_with :user, :source

  def call
    lost_premium = false

    user.with_lock do
      was_premium = user.premium?

      entitlement = user.premium_entitlements.active.find_by(source: source)
      return unless entitlement

      entitlement.update!(revoked_at: Time.current)

      lost_premium = was_premium && !user.reload.premium?
    end

    User::DowngradeToStandard.(user) if lost_premium
  end
end
