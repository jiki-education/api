require "test_helper"

class User::SubscribeToAllEmailsTest < ActiveSupport::TestCase
  test "sets all preferences to true" do
    user = create(:user)
    user.data.update!(
      receive_newsletters: false,
      receive_event_emails: false,
      receive_milestone_emails: false,
      receive_activity_emails: false
    )

    User::SubscribeToAllEmails.(user)

    user.data.reload
    assert user.data.receive_newsletters?
    assert user.data.receive_event_emails?
    assert user.data.receive_milestone_emails?
    assert user.data.receive_activity_emails?
  end

  test "works when some preferences already true" do
    user = create(:user)
    user.data.update!(receive_newsletters: false, receive_event_emails: false)

    User::SubscribeToAllEmails.(user)

    user.data.reload
    assert user.data.receive_newsletters?
    assert user.data.receive_event_emails?
    assert user.data.receive_milestone_emails?
    assert user.data.receive_activity_emails?
  end
end
