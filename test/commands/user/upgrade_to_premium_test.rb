require "test_helper"

class User::UpgradeToPremiumTest < ActiveSupport::TestCase
  test "sends welcome-to-premium email" do
    user = create(:user)

    User::SendWelcomeToPremiumEmail.expects(:call).with(user)

    User::UpgradeToPremium.(user)
  end

  test "enqueues premium badge award" do
    user = create(:user)

    assert_enqueued_with(job: AwardBadgeJob, args: [user, "premium"]) do
      User::UpgradeToPremium.(user)
    end
  end

  test "defers identify and tracks event with default source" do
    user = create(:user)

    User::Identify.expects(:defer).with(user)
    Analytics::TrackEvent.expects(:defer).with(
      user, "upgraded_to_premium", properties: { source: "stripe_checkout" }
    )

    User::UpgradeToPremium.(user)
  end

  test "uses provided source in event" do
    user = create(:user)

    User::Identify.expects(:defer).with(user)
    Analytics::TrackEvent.expects(:defer).with(
      user, "upgraded_to_premium", properties: { source: PremiumEntitlement::EXERCISM_INSIDER }
    )

    User::UpgradeToPremium.(user, source: PremiumEntitlement::EXERCISM_INSIDER)
  end
end
