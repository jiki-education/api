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
    user = user_level.user

    mail_template_to_user(
      user,
      :level_completion,
      user_level.level.slug,
      unsubscribe_key: :milestone_emails,
      context: { level: LevelDrop.new(user_level.level) }
    )
  end
end
