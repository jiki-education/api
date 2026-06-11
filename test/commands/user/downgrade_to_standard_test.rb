require "test_helper"

class User::DowngradeToStandardTest < ActiveSupport::TestCase
  test "sends subscription ended email" do
    user = create(:user)

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      User::DowngradeToStandard.(user)
    end
  end

  test "defers identify and tracks downgraded event" do
    user = create(:user)

    User::Identify.expects(:defer).with(user)
    Analytics::TrackEvent.expects(:defer).with(user, "downgraded_to_standard")

    User::DowngradeToStandard.(user)
  end
end
