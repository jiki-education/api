class Mailshot < ApplicationRecord
  # Defined here (rather than config/initializers/exceptions.rb) because the
  # namespaced constant can't be opened before Mailshot autoloads. It is
  # available app-wide wherever Mailshot is referenced.
  class UnknownSegmentError < RuntimeError; end
  class BlankBodyError < RuntimeError; end

  # Communication-preference keys a mailshot is allowed to use. Only newsletters
  # for now; expand this list (and confirm a matching receive_* preference and
  # NOTIFICATION_SLUGS entry exist) to support other kinds.
  ALLOWED_PREFERENCE_KEYS = %w[newsletters].freeze

  has_many :user_mailshots, class_name: "User::Mailshot", dependent: :destroy

  validates :slug, presence: true, uniqueness: true
  validates :subject, presence: true
  validates :email_communication_preferences_key, inclusion: { in: ALLOWED_PREFERENCE_KEYS }
  # body_markdown may be blank while drafting; presence is enforced at send time.

  # Named audience segments → lambdas returning a User relation.
  # Use merge(...) to avoid hardcoding the user_data table name.
  SEGMENTS = {
    "all_users" => -> { User.all },
    "premium_users" => -> { User.joins(:data).merge(User::Data.where(membership_type: "premium")) },
    "free_users" => -> { User.joins(:data).merge(User::Data.where(membership_type: "standard")) },
    "admin_users" => -> { User.where(admin: true) }
  }.freeze

  def ready_to_send? = body_markdown.present?
  def segment_relation(key) = SEGMENTS.fetch(key).()
  def sent_to_audience?(key) = sent_to_audiences.include?(key)
  def sent? = sent_to_audiences.any?
  def unsubscribe_key = email_communication_preferences_key.to_sym
end
