class User::Notification::SendEmail
  include Mandate

  queue_as :notifications

  initialize_with :notification

  MAILERS = {
    "User::Notifications::OnboardingOverviewNotification" => [OnboardingMailer, :overview],
    "User::Notifications::OnboardingCodingNotification" => [OnboardingMailer, :coding],
    "User::Notifications::OnboardingBuildingNotification" => [OnboardingMailer, :building],
    "User::Notifications::OnboardingPremiumNotification" => [OnboardingMailer, :premium],
    "User::Notifications::OnboardingCommunityNotification" => [OnboardingMailer, :community]
  }.freeze

  def call
    User::SendEmail.(notification) do
      mailer_class, action = MAILERS.fetch(notification.type)
      mailer_class.public_send(action, notification.user).deliver_later
    end
  end
end
