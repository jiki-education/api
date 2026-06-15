class User::Exercism::ReconcileEntitlements
  include Mandate

  initialize_with :user, is_insider: false, is_bootcamp_member: false

  def call
    reconcile_insider!
    reconcile_bootcamp!
  end

  private
  def reconcile_insider!
    if is_insider
      User::PremiumEntitlement::Grant.(user, PremiumEntitlement::EXERCISM_INSIDER)
    else
      User::PremiumEntitlement::Revoke.(user, PremiumEntitlement::EXERCISM_INSIDER)
    end
  end

  # Bootcamp membership is one-way: once granted, never revoked.
  def reconcile_bootcamp!
    return unless is_bootcamp_member

    User::PremiumEntitlement::Grant.(user, PremiumEntitlement::EXERCISM_BOOTCAMP)
  end
end
