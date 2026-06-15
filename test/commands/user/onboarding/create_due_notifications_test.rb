require "test_helper"

class User::Onboarding::CreateDueNotificationsTest < ActiveSupport::TestCase
  test "creates the day-0 notification for users created just now" do
    user = create(:user)

    User::Onboarding::CreateDueNotifications.()

    assert_equal 1, user.notifications.count
    assert_kind_of User::Notifications::OnboardingOverviewNotification, user.notifications.first
  end

  test "creates the day-1 notification for users created ~1 day ago" do
    user = create(:user)
    user.update_column(:created_at, 1.day.ago - 1.hour)

    User::Onboarding::CreateDueNotifications.()

    types = user.notifications.pluck(:type)
    assert_includes types, "User::Notifications::OnboardingCodingNotification"
  end

  test "skips users who are not confirmed" do
    user = create(:user, :unconfirmed)
    user.update_column(:created_at, 1.day.ago - 1.hour)

    User::Onboarding::CreateDueNotifications.()

    assert_equal 0, user.notifications.count
  end

  test "skips users outside the safety window" do
    user = create(:user)
    user.update_column(:created_at, 30.days.ago)

    User::Onboarding::CreateDueNotifications.()

    assert_equal 0, user.notifications.count
  end

  test "skips the premium onboarding email for premium users" do
    user = create(:user)
    make_premium(user)
    user.update_column(:created_at, 6.days.ago - 1.hour)

    User::Onboarding::CreateDueNotifications.()

    types = user.notifications.pluck(:type)
    refute_includes types, "User::Notifications::OnboardingPremiumNotification"
  end

  test "sends the premium onboarding email for standard users" do
    user = create(:user)
    user.update_column(:created_at, 6.days.ago - 1.hour)

    User::Onboarding::CreateDueNotifications.()

    types = user.notifications.pluck(:type)
    assert_includes types, "User::Notifications::OnboardingPremiumNotification"
  end

  test "is idempotent — re-running does not create duplicates" do
    user = create(:user)

    User::Onboarding::CreateDueNotifications.()
    User::Onboarding::CreateDueNotifications.()

    assert_equal 1, user.notifications.count
  end

  test "one user failing does not stop the batch" do
    user_a = create(:user)
    user_b = create(:user)

    User::Notification::Create.expects(:call).with(user_a, :onboarding_overview).raises("boom")
    User::Notification::Create.expects(:call).with(user_b, :onboarding_overview).once

    User::Onboarding::CreateDueNotifications.()
  end
end
