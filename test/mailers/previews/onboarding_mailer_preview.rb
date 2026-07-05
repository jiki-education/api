class OnboardingMailerPreview < ActionMailer::Preview
  def overview  = OnboardingMailer.overview(preview_user)
  def coding    = OnboardingMailer.coding(preview_user)
  def building  = OnboardingMailer.building(preview_user)
  def premium   = OnboardingMailer.premium(preview_user)
  def community = OnboardingMailer.community(preview_user)

  private
  # mail_to_user renders nothing unless the onboarding preference is on, so
  # force it (in memory — not persisted) for the preview.
  def preview_user
    (User.first || FactoryBot.build(:user)).tap do |user|
      user.data.receive_onboarding_emails = true
    end
  end
end
