# Learning activity notifications sent via notifications.jiki.io
# - Badge earned
# - Achievement unlocked
# - Streak reminders
#
# Users can unsubscribe via activity_emails preference.

class NotificationsMailer < ApplicationMailer
  self.email_category = :notifications

  # Example: Badge earned notification
  # def badge_earned(user, badge)
  #   with_locale(user) do
  #     @badge = badge
  #
  #     mail_to_user(
  #       user,
  #       unsubscribe_key: :activity_emails,
  #       to: user.email,
  #       subject: t('.subject', badge_name: badge.name)
  #     )
  #   end
  # end

  # Example: Achievement unlocked
  # def achievement_unlocked(user, achievement)
  #   with_locale(user) do
  #     @achievement = achievement
  #
  #     mail_to_user(
  #       user,
  #       unsubscribe_key: :activity_emails,
  #       to: user.email,
  #       subject: t('.subject', achievement_name: achievement.title)
  #     )
  #   end
  # end
end
