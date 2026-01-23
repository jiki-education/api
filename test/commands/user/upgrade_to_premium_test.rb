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

  test "returns early if user is already max" do
    user = create(:user)
    user.data.update!(membership_type: "max")

    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      User::UpgradeToPremium.(user)
    end

    # Should remain max, not downgrade to premium
    assert user.data.reload.max?
  end
end
