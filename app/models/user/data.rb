class User::Data < ApplicationRecord
  belongs_to :user

  # Membership tier checks
  def standard?
    membership_type == "standard"
  end

  def premium?
    membership_type == "premium"
  end

  def max?
    membership_type == "max"
  end

  # Payment status - whether subscription payments are current
  def subscription_paid?
    return true if standard? # Free tier is always "paid"
    return false unless stripe_subscription_status

    %w[active trialing].include?(stripe_subscription_status)
  end

  # Grace period (1 week after payment failure)
  def in_grace_period?
    return false if subscription_paid?
    return false unless payment_failed_at

    payment_failed_at > 1.week.ago
  end

  def grace_period_ends_at
    return nil unless in_grace_period?

    payment_failed_at + 1.week
  end

  # Effective access levels (for feature gating)
  def has_premium_access?
    premium? || max?
  end

  def has_max_access?
    max?
  end
end
