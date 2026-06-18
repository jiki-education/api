class User::Notification < ApplicationRecord
  self.table_name = "user_notifications"

  include Emailable
  has_email_status

  extend Mandate::Memoize

  belongs_to :user

  enum :status, { pending: 0, unread: 1, read: 2, email_only: 3 }

  scope :pending_or_unread, -> { where(status: %i[pending unread]) }
  scope :visible, -> { where(status: %i[unread read]) }

  # Onboarding notifications have no in-app surface yet; they exist solely as
  # an audit record of the email send. Override in subclasses if a notification
  # type should also appear in-app.
  def email_only? = true

  # Subclasses must declare guard_params explicitly — see Exercism's pattern.
  # Returning "" means "send once per user, ever". For per-entity notifications,
  # return a string like "Badge##{badge.id}" so the same notification type can
  # legitimately fire multiple times for different entities.
  def guard_params
    raise NotImplementedError, "#{self.class.name} must implement guard_params"
  end

  def uniqueness_key = [self.class.name, guard_params].join("|")

  before_validation on: :create do
    self.uniqueness_key = uniqueness_key
    self.status = :email_only if email_only? && status.to_s == "pending"
  end

  # Preferences are gated at the mailer level via mail_to_user(unsubscribe_key:),
  # so User::SendEmail's preference check is bypassed for notifications.
  def email_communication_preferences_key(_kind = nil) = nil

  def email_should_send?(_kind = nil)
    unread? || email_only?
  end
end
