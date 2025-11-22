# Learning notifications sent via notifications.jiki.io
# - Lesson completed
# - Achievement unlocked
# - Progress milestones
# - Streak reminders
#
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

  # Test email for verification
  def test_email(to)
    raise "test_email can only be called in test environment" unless Rails.env.test?

    mail(
      to: to,
      subject: '[TEST] Notification email from notifications.jiki.io'
    ) do |format|
      format.html { render html: '<p>This is a test notification email from notifications.jiki.io</p>'.html_safe }
      format.text { render plain: 'This is a test notification email from notifications.jiki.io' }
    end
  end

  private
  def default_from_email = Jiki.config.notifications_from_email
  def configuration_set = Jiki.config.ses_notifications_configuration_set

  # Add RFC 8058 one-click unsubscribe headers for notification emails
  def mail(**args)
    add_unsubscribe_headers!
    super(**args)
  end
end
