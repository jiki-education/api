# Learning progression emails sent via notifications.jiki.io
# - Level completion
# - (Future: chapter completion, course completion, etc.)
#
# Users can unsubscribe via milestone_emails preference.

class ProgressionMailer < ApplicationMailer
  self.email_category = :notifications

  # Sends a level completion email to a user
  #
  # @param user_level [UserLevel] The user_level record that was completed
  def level_completed(user_level)
    @user = user_level.user
    @level = user_level.level

    # Get translated content for user's locale
    content = @level.content_for_locale(@user.locale)
    @subject = content[:milestone_email_subject]
    @content_markdown = content[:milestone_email_content_markdown]
    @image_url = @level.milestone_email_image_url

    return unless @subject.present? && @content_markdown.present?

    mail_to_user(@user, unsubscribe_key: :milestone_emails, subject: @subject)
  end
end
