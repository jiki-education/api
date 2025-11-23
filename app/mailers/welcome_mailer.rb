class WelcomeMailer < ApplicationMailer
  # Sends a welcome email to a new user
  #
  # @param user [User] The user to send the welcome email to
  # @param login_url [String] URL for the user to log in and start learning
  def welcome(user, login_url:)
    with_locale(user) do
      @user = user
      @login_url = login_url

      mail(
        to: user.email,
        subject: t(".subject")
      )
    end
  end

  # Test email for verification
  def test_email(to)
    unless Rails.env.test? || to == "jez.walker@gmail.com"
      raise "test_email can only be called in test environment or to jez.walker@gmail.com"
    end

    mail(
      to: to,
      subject: '[TEST] Transactional email from mail.jiki.io'
    ) do |format|
      format.html { render html: '<p>This is a test transactional email from mail.jiki.io</p>'.html_safe }
      format.text { render plain: 'This is a test transactional email from mail.jiki.io' }
    end
  end
end
