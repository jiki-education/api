require "test_helper"

class SerializeSettingsTest < ActiveSupport::TestCase
  test "serializes all settings fields" do
    user = create(:user,
      name: "Test User",
      handle: "test-handle",
      email: "test@example.com",
      confirmed_at: Time.current,
      locale: "en")

    result = SerializeSettings.(user)

    expected = {
      name: "Test User",
      handle: "test-handle",
      email: "test@example.com",
      unconfirmed_email: nil,
      email_confirmed: true,
      locale: "en",
      receive_product_updates: true,
      receive_event_emails: true,
      receive_milestone_emails: true,
      receive_activity_emails: true
    }

    assert_equal expected, result
  end

  test "serializes notification preferences when disabled" do
    user = create(:user)
    user.data.update!(
      receive_product_updates: false,
      receive_event_emails: false,
      receive_milestone_emails: true,
      receive_activity_emails: false
    )

    result = SerializeSettings.(user)

    refute result[:receive_product_updates]
    refute result[:receive_event_emails]
    assert result[:receive_milestone_emails]
    refute result[:receive_activity_emails]
  end

  test "serializes user with unconfirmed email" do
    user = create(:user, confirmed_at: nil)

    result = SerializeSettings.(user)

    refute result[:email_confirmed]
  end

  test "serializes user with pending email change" do
    user = create(:user, confirmed_at: Time.current, unconfirmed_email: "new@example.com")

    result = SerializeSettings.(user)

    assert result[:email_confirmed]
    assert_equal "new@example.com", result[:unconfirmed_email]
  end

  test "serializes user with different locale" do
    user = create(:user, locale: "hu")

    result = SerializeSettings.(user)

    assert_equal "hu", result[:locale]
  end
end
