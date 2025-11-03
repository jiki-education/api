module Emailable
  extend ActiveSupport::Concern

  included do
    enum :email_status, { pending: 0, skipped: 1, sent: 2, failed: 3 }, prefix: :email
  end

  # Override in including class to specify which communication preference key to check
  # Return nil to always send emails (no preference checking)
  def email_communication_preferences_key
    raise "email_communication_preferences_key must be implemented by a child class"
  end

  # Override in including class to add custom logic for whether an email should be sent
  # This is called before checking user preferences and is useful for checking if
  # templates exist, if the record is in the right state, etc.
  def email_should_send?
    true
  end
end
