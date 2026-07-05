require "test_helper"

class User::Notification::SendEmailTest < ActiveSupport::TestCase
  test "delivers the matching mailer action and marks email_sent" do
    user = create(:user)
    notification = User::Notifications::OnboardingCodingNotification.create!(user:)

    assert_enqueued_with(
      job: ActionMailer::MailDeliveryJob,
      args: ["OnboardingMailer", "coding", "deliver_now", { args: [user] }]
    ) do
      User::Notification::SendEmail.(notification)
    end

    assert notification.reload.email_sent?
  end

  test "routes each onboarding kind to the right action" do
    user = create(:user)

    Prosopite.pause do
      {
        User::Notifications::OnboardingOverviewNotification => "overview",
        User::Notifications::OnboardingCodingNotification => "coding",
        User::Notifications::OnboardingBuildingNotification => "building",
        User::Notifications::OnboardingPremiumNotification => "premium",
        User::Notifications::OnboardingCommunityNotification => "community"
      }.each do |klass, expected_action|
        notification = klass.create!(user:)

        assert_enqueued_with(
          job: ActionMailer::MailDeliveryJob,
          args: ["OnboardingMailer", expected_action, "deliver_now", { args: [user] }]
        ) do
          User::Notification::SendEmail.(notification)
        end
      end
    end
  end

  test "second call is a no-op (idempotent via email_status)" do
    user = create(:user)
    notification = User::Notifications::OnboardingOverviewNotification.create!(user:)

    User::Notification::SendEmail.(notification)
    assert notification.reload.email_sent?

    OnboardingMailer.expects(:overview).never
    User::Notification::SendEmail.(notification)
  end
end
