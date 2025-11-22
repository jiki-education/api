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
  # TODO: Implement when User model exists
  # def monthly_newsletter(user)
  #   return unless user.marketing_emails_enabled?
  #
  #   @user = user
  #   @unsubscribe_url = unsubscribe_url(token: user.unsubscribe_token)
  #
  #   mail(
  #     to: user.email,
  #     subject: "What's new at Jiki - #{Date.current.strftime('%B %Y')}"
  #   )
  # end

  # Example: Feature announcement
  # TODO: Implement when User model exists
  # def feature_announcement(user, feature)
  #   return unless user.marketing_emails_enabled?
  #
  #   @user = user
  #   @feature = feature
  #   @unsubscribe_url = unsubscribe_url(token: user.unsubscribe_token)
  #
  #   mail(
  #     to: user.email,
  #     subject: "New feature: #{feature.title}"
  #   )
  # end

  # Test email for verification
  def test_email(to)
    raise "test_email can only be called in test environment" unless Rails.env.test?

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
