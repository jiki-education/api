require "test_helper"

class MailshotTest < ActiveSupport::TestCase
  test "defaults the preference key to newsletters" do
    assert_equal "newsletters", create(:mailshot).email_communication_preferences_key
  end

  test "rejects a preference key outside the allowed list" do
    mailshot = build(:mailshot, email_communication_preferences_key: "event_emails")

    refute mailshot.valid?
    assert_includes mailshot.errors[:email_communication_preferences_key], "is not included in the list"
  end
end
