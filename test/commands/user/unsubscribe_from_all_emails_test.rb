require "test_helper"

class User::UnsubscribeFromAllEmailsTest < ActiveSupport::TestCase
  test "sets all preferences to false" do
    user = create(:user)
    assert user.data.receive_newsletters?
    assert user.data.receive_event_emails?
    assert user.data.receive_milestone_emails?
    assert user.data.receive_activity_emails?

    User::UnsubscribeFromAllEmails.(user)

    user.data.reload
    refute user.data.receive_newsletters?
    refute user.data.receive_event_emails?
    refute user.data.receive_milestone_emails?
    refute user.data.receive_activity_emails?
  end

  test "works when some preferences already false" do
    user = create(:user)
    user.data.update!(receive_newsletters: false, receive_event_emails: false)

    User::UnsubscribeFromAllEmails.(user)

    user.data.reload
    refute user.data.receive_newsletters?
    refute user.data.receive_event_emails?
    refute user.data.receive_milestone_emails?
    refute user.data.receive_activity_emails?
  end
end
