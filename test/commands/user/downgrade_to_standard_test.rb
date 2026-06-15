require "test_helper"

class User::DowngradeToStandardTest < ActiveSupport::TestCase
  test "downgrades premium user to standard" do
    user = create(:user)
    user.data.update!(membership_type: "premium")

    User::DowngradeToStandard.(user)

    assert user.data.reload.standard?
  end

  test "sends subscription ended email when downgrading from premium" do
    user = create(:user)
    user.data.update!(membership_type: "premium")

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      User::DowngradeToStandard.(user)
    end
  end

  test "returns early if user is already standard" do
    user = create(:user)
    assert user.data.standard?

    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      User::DowngradeToStandard.(user)
    end

    assert user.data.reload.standard?
  end

  test "defers downgraded_to_standard event on downgrade" do
    user = create(:user)
    user.data.update!(membership_type: "premium")

    User::Identify.expects(:defer).with(user)
    Analytics::TrackEvent.expects(:defer).with(user, "downgraded_to_standard")

    User::DowngradeToStandard.(user)
  end

  test "does not fire event when user already standard" do
    user = create(:user)

    User::Identify.expects(:defer).never
    Analytics::TrackEvent.expects(:defer).never

    User::DowngradeToStandard.(user)
  end

  test "does not downgrade when an active premium entitlement still covers the user" do
    user = create(:user)
    user.data.update!(membership_type: "premium")
    create(:premium_entitlement, :insider, user:)

    User::Identify.expects(:defer).never
    Analytics::TrackEvent.expects(:defer).never

    User::DowngradeToStandard.(user)

    assert_equal "premium", user.data.reload.membership_type
  end
end
