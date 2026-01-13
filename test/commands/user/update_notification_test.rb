require "test_helper"

class User::UpdateNotificationTest < ActiveSupport::TestCase
  test "updates notification preference to false" do
    user = create(:user)
    assert user.data.receive_product_updates

    User::UpdateNotification.(user, "product_updates", false)

    refute user.data.reload.receive_product_updates
  end

  test "updates notification preference to true" do
    user = create(:user)
    user.data.update!(receive_event_emails: false)

    User::UpdateNotification.(user, "event_emails", true)

    assert user.data.reload.receive_event_emails
  end

  test "raises on invalid slug" do
    user = create(:user)

    assert_raises InvalidNotificationSlugError do
      User::UpdateNotification.(user, "invalid_slug", false)
    end
  end

  test "updates milestone_emails preference" do
    user = create(:user)

    User::UpdateNotification.(user, "milestone_emails", false)

    refute user.data.reload.receive_milestone_emails
  end

  test "updates activity_emails preference" do
    user = create(:user)

    User::UpdateNotification.(user, "activity_emails", false)

    refute user.data.reload.receive_activity_emails
  end
end
