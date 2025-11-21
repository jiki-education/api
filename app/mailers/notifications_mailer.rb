# Learning notifications sent via notifications.jiki.io
# - Lesson completed
# - Achievement unlocked
# - Progress milestones
# - Streak reminders
#
# High volume (~600k/month → 3.6M/month)
# Users can unsubscribe from these in preferences

class NotificationsMailer < ApplicationMailer
  default from: -> { Jiki.config.notifications_from_email }

  # Example: Lesson completed notification
  # TODO: Implement when User and Lesson models exist
  # def lesson_completed(user, lesson)
  #   return unless user.notifications_enabled?
  #
  #   @user = user
  #   @lesson = lesson
  #   @next_lesson = lesson.next_lesson
  #
  #   mail(
  #     to: user.email,
  #     subject: "🎉 You completed #{lesson.title}!"
  #   )
  # end

  # Example: Achievement unlocked
  # TODO: Implement when User and Achievement models exist
  # def achievement_unlocked(user, achievement)
  #   return unless user.notifications_enabled?
  #
  #   @user = user
  #   @achievement = achievement
  #
  #   mail(
  #     to: user.email,
  #     subject: "🏆 Achievement unlocked: #{achievement.title}"
  #   )
  # end

  # Example: Daily streak reminder
  # TODO: Implement when User model exists
  # def streak_reminder(user)
  #   return unless user.notifications_enabled?
  #   return unless user.streak_reminders_enabled?
  #
  #   @user = user
  #   @streak_days = user.current_streak
  #
  #   mail(
  #     to: user.email,
  #     subject: "🔥 Keep your #{@streak_days}-day streak going!"
  #   )
  # end

  # Test email for verification
  def test_email(to)
    mail(
      to: to,
      subject: '[TEST] Notification email from notifications.jiki.io'
    ) do |format|
      format.html { render html: '<p>This is a test notification email from notifications.jiki.io</p>'.html_safe }
      format.text { render plain: 'This is a test notification email from notifications.jiki.io' }
    end
  end

  private
  def default_from_email
    Jiki.config.notifications_from_email
  end

  def configuration_set
    Jiki.config.ses_notifications_configuration_set
  end
end
