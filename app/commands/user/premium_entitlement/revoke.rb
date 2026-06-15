class User::PremiumEntitlement::Revoke
  include Mandate

  initialize_with :user, :source

  def call
    return unless entitlement

    entitlement.update!(revoked_at: Time.current)

    return if stripe_providing_premium?

    User::DowngradeToStandard.(user)
  end

  private
  memoize
  def entitlement = user.premium_entitlements.active.find_by(source: source)

  # True when Stripe is currently entitling the user to premium, so revoking
  # this entitlement shouldn't flip them back to standard.
  def stripe_providing_premium?
    user.data.subscription_status_active? ||
      user.data.subscription_status_payment_failed? ||
      user.data.subscription_status_cancelling?
  end
end
