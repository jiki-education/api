require "test_helper"

class User::SendWelcomeEmailTest < ActiveSupport::TestCase
  test "delivers the welcome email and marks status sent" do
    user = create(:user)

    assert_enqueued_with(
      job: MailDeliveryJob,
      args: ["AccountMailer", "welcome", "deliver_now", { args: [user] }]
    ) do
      User::SendWelcomeEmail.(user)
    end

    assert user.data.reload.welcome_email_sent?
  end

  test "is idempotent — second call does nothing" do
    user = create(:user)

    User::SendWelcomeEmail.(user)
    assert user.data.reload.welcome_email_sent?

    AccountMailer.expects(:welcome).never

    User::SendWelcomeEmail.(user)
  end
end
