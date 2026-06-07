require "test_helper"

class User::SendWelcomeToPremiumEmailTest < ActiveSupport::TestCase
  test "delivers the welcome-to-premium email and marks status sent" do
    user = create(:user)

    assert_enqueued_with(
      job: ActionMailer::MailDeliveryJob,
      args: ["PremiumMailer", "welcome_to_premium", "deliver_now", { args: [user] }]
    ) do
      User::SendWelcomeToPremiumEmail.(user)
    end

    assert user.data.reload.welcome_to_premium_email_sent?
  end

  test "is idempotent — second call does nothing" do
    user = create(:user)

    User::SendWelcomeToPremiumEmail.(user)
    assert user.data.reload.welcome_to_premium_email_sent?

    PremiumMailer.expects(:welcome_to_premium).never

    User::SendWelcomeToPremiumEmail.(user)
  end
end
