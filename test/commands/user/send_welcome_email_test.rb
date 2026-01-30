require "test_helper"

class User::SendWelcomeEmailTest < ActiveSupport::TestCase
  test ".defer() enqueues job with correct queue" do
    user = create(:user)

    assert_enqueued_with(
      job: MandateJob,
      args: ["User::SendWelcomeEmail", user],
      queue: "mailers"
    ) do
      User::SendWelcomeEmail.defer(user)
    end
  end

  test "sends welcome email when job is performed" do
    user = create(:user)

    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      perform_enqueued_jobs do
        User::SendWelcomeEmail.defer(user)
      end
    end
  end

  test "includes correct login URL for test environment" do
    user = create(:user)

    command = User::SendWelcomeEmail.new(user)
    assert_equal "http://test.host/login", command.send(:login_url)
  end

  test "delivers email with correct recipient" do
    user = create(:user, email: "test@example.com")

    perform_enqueued_jobs do
      User::SendWelcomeEmail.defer(user)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal ["test@example.com"], email.to
  end

  test "email uses user's locale" do
    user = create(:user, locale: "hu")

    perform_enqueued_jobs do
      User::SendWelcomeEmail.defer(user)
    end

    email = ActionMailer::Base.deliveries.last
    # Subject should be in Hungarian
    assert_equal I18n.t("account_mailer.welcome.subject", locale: "hu"), email.subject
  end
end
