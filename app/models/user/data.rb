class User::Data < ApplicationRecord
  include Emailable
  has_email_status :welcome
  has_email_status :welcome_to_premium

  belongs_to :user

  # Generate unsubscribe token for new records
  before_create :generate_unsubscribe_token!
  before_create :set_default_timezone!

  # Welcome emails are transactional — no preference check.
  def email_communication_preferences_key(_kind = nil) = nil

  # Notification preference slugs mapped to column names
  NOTIFICATION_SLUGS = {
    "newsletters" => :receive_newsletters,
    "event_emails" => :receive_event_emails,
    "milestone_emails" => :receive_milestone_emails,
    "activity_emails" => :receive_activity_emails
  }.freeze

  def self.valid_notification_slug?(slug)
    NOTIFICATION_SLUGS.key?(slug)
  end

  def self.notification_column_for(slug)
    NOTIFICATION_SLUGS[slug]
  end

  # Subscription status enum
  enum :subscription_status, {
    never_subscribed: 0,
    incomplete: 1,
    active: 2,
    payment_failed: 3,
    cancelling: 4,
    canceled: 5
  }, prefix: true

  # Derives "Stripe currently entitles the user to premium" from the
  # subscription columns.
  def stripe_active?
    return true if subscription_status_active?
    return true if subscription_status_cancelling?
    return true if subscription_status_payment_failed? && stripe_subscription_status != "unpaid"

    false
  end

  # Billing interval checks
  def monthly? = subscription_interval == "monthly"
  def annual? = subscription_interval == "annual"

  # Payment status - whether subscription payments are current. Users
  # without any Stripe subscription state ("never subscribed") are trivially
  # "paid" — they have nothing to pay.
  def subscription_paid?
    return true if subscription_status_never_subscribed?

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

  # Subscription state helpers
  def current_subscription = subscriptions.find { |s| s['ended_at'].nil? }

  def can_checkout?
    subscription_status.in?(%w[never_subscribed canceled])
  end

  def can_change_interval?
    subscription_status.in?(%w[active payment_failed cancelling])
  end

  # Email validity checks
  def email_valid? = email_bounced_at.nil?
  def may_receive_emails? = email_complaint_at.nil?

  private
  def generate_unsubscribe_token!
    self.unsubscribe_token ||= SecureRandom.uuid
  end

  def set_default_timezone!
    self.timezone ||= "UTC".freeze
  end
end
