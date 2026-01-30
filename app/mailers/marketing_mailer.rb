# Marketing emails sent via hello.jiki.io
# - Monthly newsletters
# - Feature announcements
# - Product updates
#
# Users can unsubscribe via one-click unsubscribe

class MarketingMailer < ApplicationMailer
  default from: -> { Jiki.config.marketing_from_email },
    reply_to: -> { Jiki.config.support_email }

  # Example: Monthly newsletter
  # def monthly_newsletter(user)
  #   return unless user.data.receive_newsletters?
  #
  #   @user = user
  #   @unsubscribe_key = :newsletters
  #
  #   mail(
  #     to: user.email,
  #     subject: "What's new at Jiki - #{Date.current.strftime('%B %Y')}"
  #   )
  # end

  # Example: Event announcement
  # def event_announcement(user, event)
  #   return unless user.data.receive_event_emails?
  #
  #   @user = user
  #   @event = event
  #   @unsubscribe_key = :event_emails
  #
  #   mail(
  #     to: user.email,
  #     subject: "Join us: #{event.title}"
  #   )
  # end

  # Test email for verification
  def test_email(to)
    unless Rails.env.test? || to == "jez.walker@gmail.com"
      raise "test_email can only be called in test environment or to jez.walker@gmail.com"
    end

    mail(
      to: to,
      subject: '[TEST] Marketing email from hello.jiki.io'
    ) do |format|
      format.html { render html: '<p>This is a test marketing email from hello.jiki.io</p>'.html_safe }
      format.text { render plain: 'This is a test marketing email from hello.jiki.io' }
    end
  end

  private
  def default_from_email = Jiki.config.marketing_from_email
  def configuration_set = Jiki.config.ses_marketing_configuration_set
  def reply_to_email = Jiki.config.support_email

  # Add RFC 8058 one-click unsubscribe headers for marketing emails
  def mail(**args)
    add_unsubscribe_headers!
    super(**args)
  end
end
