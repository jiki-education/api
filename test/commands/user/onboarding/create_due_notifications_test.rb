require "test_helper"

class User::Onboarding::CreateDueNotificationsTest < ActiveSupport::TestCase
  LAUNCH = User::Onboarding::CreateDueNotifications::LAUNCH_DATE

  # Travel well past launch so users dated relative to "now" are post-launch and
  # anchor on created_at. The pre-launch tests re-travel to launch-relative times.
  setup { travel_to LAUNCH.in_time_zone + 40.days }

  test "creates the day-1 overview notification for users created ~1 day ago" do
    user = create(:user)
    user.update_column(:created_at, 1.day.ago - 1.hour)

    User::Onboarding::CreateDueNotifications.()

    assert_equal 1, user.notifications.count
    assert_kind_of User::Notifications::OnboardingOverviewNotification, user.notifications.first
  end

  test "creates the day-2 coding notification for users created ~2 days ago" do
    user = create(:user)
    user.update_column(:created_at, 2.days.ago - 1.hour)

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
    user.update_column(:created_at, 4.days.ago - 1.hour)

    User::Onboarding::CreateDueNotifications.()

    types = user.notifications.pluck(:type)
    refute_includes types, "User::Notifications::OnboardingPremiumNotification"
  end

  test "sends the premium onboarding email for standard users" do
    user = create(:user)
    user.update_column(:created_at, 4.days.ago - 1.hour)

    User::Onboarding::CreateDueNotifications.()

    types = user.notifications.pluck(:type)
    assert_includes types, "User::Notifications::OnboardingPremiumNotification"
  end

  test "is idempotent — re-running does not create duplicates" do
    user = create(:user)
    user.update_column(:created_at, 1.day.ago - 1.hour)

    User::Onboarding::CreateDueNotifications.()
    User::Onboarding::CreateDueNotifications.()

    assert_equal 1, user.notifications.count
  end

  test "one user failing does not stop the batch" do
    user_a = create(:user)
    user_b = create(:user)
    user_a.update_column(:created_at, 1.day.ago - 1.hour)
    user_b.update_column(:created_at, 1.day.ago - 1.hour)

    User::Notification::Create.expects(:call).with(user_a, :onboarding_overview).raises("boom")
    User::Notification::Create.expects(:call).with(user_b, :onboarding_overview).once

    User::Onboarding::CreateDueNotifications.()
  end

  test "post-launch users anchor on created_at, not the launch date" do
    user = create(:user)
    user.update_column(:created_at, 1.day.ago - 1.hour) # ~launch+39d, post-launch

    User::Onboarding::CreateDueNotifications.()

    # Anchored on created_at → due for day 1. If it anchored on the launch date
    # they'd be ~40 days past launch and get nothing.
    assert_equal ["User::Notifications::OnboardingOverviewNotification"], user.notifications.pluck(:type)
  end

  test "re-anchors pre-launch users to the launch date, so day 1 lands the day after launch" do
    travel_to LAUNCH.in_time_zone + 1.day + 12.hours do
      user = create(:user)
      # Signed up long before launch, at 09:00.
      user.update_column(:created_at, (LAUNCH - 30.days).in_time_zone + 9.hours)

      User::Onboarding::CreateDueNotifications.()

      # Without re-anchoring they'd be 30 days old and get nothing; anchored on
      # launch (keeping the 09:00 time-of-day) they're due for day 1 only.
      assert_equal ["User::Notifications::OnboardingOverviewNotification"], user.notifications.pluck(:type)
    end
  end

  test "sends nothing to pre-launch users on launch day itself (first email is day 1)" do
    travel_to LAUNCH.in_time_zone + 6.hours do
      user = create(:user)
      user.update_column(:created_at, (LAUNCH - 10.days).in_time_zone + 3.hours)

      User::Onboarding::CreateDueNotifications.()

      assert_equal 0, user.notifications.count
    end
  end
end
