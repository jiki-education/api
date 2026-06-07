module Emailable
  extend ActiveSupport::Concern

  STATUSES = { pending: 0, skipped: 1, sent: 2, failed: 3 }.freeze

  class_methods do
    def has_email_status(kind = nil)
      column = kind ? :"#{kind}_email_status" : :email_status
      prefix = kind ? :"#{kind}_email" : :email
      enum column, STATUSES, prefix: prefix
    end
  end

  # Override in including class to specify which communication preference key to check
  # for the given kind. Return nil to always send emails (no preference checking).
  def email_communication_preferences_key(_kind = nil)
    raise "email_communication_preferences_key must be implemented by a child class"
  end

  # Override in including class to add custom logic for whether an email should be sent.
  def email_should_send?(_kind = nil)
    true
  end
end
