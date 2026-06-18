require "test_helper"

class User::Notification::CreateTest < ActiveSupport::TestCase
  test "creates the notification" do
    user = create(:user)

    notification = User::Notification::Create.(user, :onboarding_overview)

    assert_kind_of User::Notifications::OnboardingOverviewNotification, notification
    assert_equal user, notification.user
    assert notification.email_only?
  end

  test "defers SendEmail with a 5 second wait" do
    user = create(:user)

    assert_enqueued_with(job: MandateJob) do
      User::Notification::Create.(user, :onboarding_overview)
    end
  end

  test "is idempotent — second call returns the existing notification" do
    user = create(:user)

    first = User::Notification::Create.(user, :onboarding_overview)
    second = User::Notification::Create.(user, :onboarding_overview)

    assert_equal first.id, second.id
    assert_equal 1, user.notifications.count
  end

  test "different types produce different notifications" do
    user = create(:user)

    User::Notification::Create.(user, :onboarding_overview)
    User::Notification::Create.(user, :onboarding_coding)

    assert_equal 2, user.notifications.count
  end
end
