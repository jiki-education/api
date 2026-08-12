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

  # Draft locales are selectable: a user can commit to one before it ships,
  # and we hold that choice until it does. Resolved lazily (rather than at
  # class-load) so the locale sets can be swapped in tests.
  validates :explicit_locale,
    inclusion: { in: ->(_) { I18n::ALL_LOCALES } },
    allow_nil: true

  # Locale is derived, never stored directly: an explicit user choice wins
  # while that locale is live, then the best match from the browser's
  # Accept-Language preferences (stored in locales), then the default.
  # Assigning locale records an explicit choice.
  def locale = live_explicit_locale || locale_from_preferences || I18n.default_locale.to_s

  def locale=(value)
    self.explicit_locale = value.presence
  end

  # Every locale (live or draft) the user could plausibly want: their explicit
  # choice first, then the locale they're actually served, then the rest of
  # their Accept-Language preferences normalised into our locale forms. The FE
  # decides which of these are worth surfacing.
  def available_locales = [selected_locale, locale, *User::DetermineLocales.(locales)].compact.uniq

  # The stored choice, but only while it's still a locale we recognise. A value
  # that has since been dropped from both the live and draft sets is treated as
  # though it were never set, rather than surfaced as a selection the user can't
  # act on.
  def selected_locale
    return nil unless I18n::ALL_LOCALES.include?(explicit_locale)

    explicit_locale
  end

  # Notification preference slugs mapped to column names
  NOTIFICATION_SLUGS = {
    "newsletters" => :receive_newsletters,
    "event_emails" => :receive_event_emails,
    "milestone_emails" => :receive_milestone_emails,
    "activity_emails" => :receive_activity_emails,
    "onboarding_emails" => :receive_onboarding_emails
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

  # Membership tier checks
  def standard? = membership_type == "standard"
  def premium? = membership_type == "premium"

  # Billing interval checks
  def monthly? = subscription_interval == "monthly"
  def annual? = subscription_interval == "annual"

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
  # An explicit choice only drives what we serve while that locale is live.
  # Picking a draft locale records the intent (and keeps surfacing it via
  # selected_locale) but must not strand the user on content that doesn't
  # exist yet, so until it ships we fall through to the usual negotiation.
  def live_explicit_locale
    return nil unless I18n::SUPPORTED_LOCALES.include?(explicit_locale)

    explicit_locale
  end

  # Negotiate the browser's Accept-Language preferences (stored in locales)
  # down to a single supported content locale, or nil when none maps to a
  # live locale.
  def locale_from_preferences = User::DetermineLocale.(locales)

  def generate_unsubscribe_token!
    self.unsubscribe_token ||= SecureRandom.uuid
  end

  def set_default_timezone!
    self.timezone ||= "UTC".freeze
  end
end
