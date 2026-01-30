require "test_helper"

class SerializeEmailPreferencesTest < ActiveSupport::TestCase
  test "serializes all preferences" do
    user = create(:user, email: "test@example.com")

    expected = {
      email: "test@example.com",
      newsletters: true,
      event_emails: true,
      milestone_emails: true,
      activity_emails: true
    }

    assert_equal expected, SerializeEmailPreferences.(user)
  end

  test "reflects disabled preferences" do
    user = create(:user, email: "test@example.com")
    user.data.update!(
      receive_newsletters: false,
      receive_event_emails: false,
      receive_milestone_emails: true,
      receive_activity_emails: false
    )

    expected = {
      email: "test@example.com",
      newsletters: false,
      event_emails: false,
      milestone_emails: true,
      activity_emails: false
    }

    assert_equal expected, SerializeEmailPreferences.(user)
  end
end
