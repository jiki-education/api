require "test_helper"

class User::UpgradeToMaxTest < ActiveSupport::TestCase
  test "upgrades standard user to max" do
    user = create(:user)
    assert user.data.standard?

    User::UpgradeToMax.(user)

    assert user.data.reload.max?
  end

  test "upgrades premium user to max" do
    user = create(:user)
    user.data.update!(membership_type: "premium")

    User::UpgradeToMax.(user)

    assert user.data.reload.max?
  end

  test "sends welcome email when upgrading from standard" do
    user = create(:user)

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      User::UpgradeToMax.(user)
    end
  end

  test "sends welcome email when upgrading from premium" do
    user = create(:user)
    user.data.update!(membership_type: "premium")

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      User::UpgradeToMax.(user)
    end
  end

  test "returns early if user is already max" do
    user = create(:user)
    user.data.update!(membership_type: "max")

    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      User::UpgradeToMax.(user)
    end

    assert user.data.reload.max?
  end
end
