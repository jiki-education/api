require "test_helper"

class User::UpgradeToPremiumTest < ActiveSupport::TestCase
  test "upgrades standard user to premium" do
    user = create(:user)
    assert user.data.standard?

    User::UpgradeToPremium.(user)

    assert user.data.reload.premium?
  end

  test "sends welcome email when upgrading from standard" do
    user = create(:user)

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      User::UpgradeToPremium.(user)
    end
  end

  test "returns early if user is already premium" do
    user = create(:user)
    user.data.update!(membership_type: "premium")

    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      User::UpgradeToPremium.(user)
    end

    assert user.data.reload.premium?
  end

  test "enqueues premium badge award when upgrading" do
    user = create(:user)

    assert_enqueued_with(job: AwardBadgeJob, args: [user, 'premium']) do
      User::UpgradeToPremium.(user)
    end
  end

  test "defers upgraded_to_premium event on upgrade" do
    user = create(:user, created_at: 7.days.ago)

    Analytics::TrackEvent.expects(:defer).with(
      user,
      "upgraded_to_premium",
      properties: { source: "stripe_checkout", days_since_signup: 7 }
    )

    User::UpgradeToPremium.(user)
  end

  test "uses provided source in event" do
    user = create(:user, created_at: 3.days.ago)

    Analytics::TrackEvent.expects(:defer).with(
      user,
      "upgraded_to_premium",
      properties: { source: "admin_grant", days_since_signup: 3 }
    )

    User::UpgradeToPremium.(user, source: "admin_grant")
  end

  test "does not fire event when user already premium" do
    user = create(:user)
    user.data.update!(membership_type: "premium")

    Analytics::TrackEvent.expects(:defer).never

    User::UpgradeToPremium.(user)
  end
end
