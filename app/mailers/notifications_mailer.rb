# Learning activity notifications sent via notifications.jiki.io
# - Badge earned
# - Achievement unlocked
# - Streak reminders
#
# Users can unsubscribe via activity_emails preference.

class NotificationsMailer < ApplicationMailer
  self.email_category = :notifications

  # Sends a badge earned notification to a user
  #
  # @param user [User] The user who earned the badge
  # @param badge [Badge] The badge that was earned
  def badge_earned(user, badge)
    @user = user
    @badge = badge

    # Get translated content for user's locale
    content = badge.content_for_locale(user.locale)
    @subject = content[:email_subject]
    @content_markdown = content[:email_content_markdown]
    @image_url = badge.email_image_url

    return unless @subject.present? && @content_markdown.present?

    mail_to_user(@user, unsubscribe_key: :activity_emails, subject: @subject)
  end
end
