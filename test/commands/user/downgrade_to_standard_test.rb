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
end
