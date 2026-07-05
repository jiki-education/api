# Onboarding drip emails sent on a cadence after signup confirmation.
# Driven by User::Onboarding::CreateDueNotifications (recurring task) which
# creates User::Notifications::Onboarding* records; each notification then
# triggers the matching mailer action.
#
# Users can unsubscribe via the onboarding_emails preference. The premium
# action is suppressed for users already on a premium tier (filter in the
# finder command — not here — so this mailer remains preference-only).

class OnboardingMailer < ApplicationMailer
  self.email_category = :notifications

  # Content-hashed header image filenames (see scripts/upload_email_images.sh).
  # The hash lets the CDN objects be served with immutable/infinite caching —
  # regenerate the hash and update the entry whenever an image changes.
  HEADER_IMAGES = {
    overview: "onboarding-overview-59828.jpg",
    coding: "onboarding-coding-cebdf.jpg",
    building: "onboarding-building-c8d7e.jpg",
    premium: "onboarding-premium-70c37.jpg",
    community: "onboarding-community-5a9bf.jpg"
  }.freeze

  def overview(user)   = send_onboarding(user, :overview)
  def coding(user)     = send_onboarding(user, :coding)
  def building(user)   = send_onboarding(user, :building)
  def premium(user)    = send_onboarding(user, :premium)
  def community(user)  = send_onboarding(user, :community)

  private
  def send_onboarding(user, action)
    @user = user
    @year = Time.current.year
    @header_image = HEADER_IMAGES.fetch(action)
    mail_to_user(user, unsubscribe_key: :onboarding_emails)
  end

  # Provide %{year} to the i18n-derived subject. Runs inside mail_to_user's
  # I18n.with_locale block, so the subject is still localised correctly.
  def default_i18n_subject(interpolations = {})
    super(year: Time.current.year, **interpolations)
  end
end
