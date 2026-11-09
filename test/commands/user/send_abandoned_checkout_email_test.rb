require "test_helper"

class User::SendAbandonedCheckoutEmailTest < ActiveSupport::TestCase
  test "delivers the abandoned checkout email and marks status sent" do
    user = create(:user)

    assert_enqueued_with(
      job: MailDeliveryJob,
      args: ["PremiumMailer", "abandoned_checkout", "deliver_now", { args: [user] }]
    ) do
      User::SendAbandonedCheckoutEmail.(user)
    end

    assert user.data.reload.abandoned_checkout_email_sent?
  end

  test "sends at most once across several expired sessions" do
    user = create(:user)

    User::SendAbandonedCheckoutEmail.(user)
    assert user.data.reload.abandoned_checkout_email_sent?

    PremiumMailer.expects(:abandoned_checkout).never

    User::SendAbandonedCheckoutEmail.(user)
  end
end
