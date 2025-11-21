class User::Data < ApplicationRecord
  belongs_to :user

  # Generate unsubscribe token for new records
  before_create :generate_unsubscribe_token

  # Subscription status enum
  enum :subscription_status, {
    never_subscribed: 0,
    incomplete: 1,
    active: 2,
    payment_failed: 3,
    cancelling: 4,
    canceled: 5
  }, prefix: true

  # Membership tier checks
  def standard? = membership_type == "standard"
  def premium? = membership_type == "premium"
  def max? = membership_type == "max"

  # Payment status - whether subscription payments are current
  def subscription_paid?
    return true if standard? # Free tier is always "paid"

    subscription_valid_until.present? && subscription_valid_until > Time.current
  end

  # Grace period (1 week after payment failure)
  def in_grace_period?
    return false unless subscription_status_payment_failed?
    return false unless subscription_valid_until.present?

    grace_period_ends_at > Time.current
  end

  def grace_period_ends_at
    subscription_valid_until + 7.days if subscription_valid_until.present?
  end

  # Effective access levels (for feature gating)
  def has_premium_access?
    premium? || max?
  end

  def has_max_access?
    max?
  end

  # Subscription state helpers
  def can_checkout?
    subscription_status.in?(%w[never_subscribed canceled])
  end

  def can_change_tier?
    subscription_status.in?(%w[active payment_failed cancelling])
  end

  def current_subscription
    subscriptions.find { |s| s['ended_at'].nil? }
  end

  private
  def generate_unsubscribe_token
    self.unsubscribe_token ||= SecureRandom.uuid
  end
end
