class ApplicationMailer < ActionMailer::Base
  layout "mailer"
  helper_method :unsubscribe_url, :markdown_to_html, :markdown_to_text

  # Email configuration by category
  # Each mailer must set email_category to one of these keys
  EMAIL_CONFIGS = {
    transactional: {
      from_email: Jiki.config.mail_from_email,
      configuration_set: Jiki.config.ses_mail_configuration_set
    },
    notifications: {
      from_email: Jiki.config.notifications_from_email,
      configuration_set: Jiki.config.ses_notifications_configuration_set
    },
    marketing: {
      from_email: Jiki.config.marketing_from_email,
      configuration_set: Jiki.config.ses_marketing_configuration_set
    }
  }.freeze

  class_attribute :email_category

  # Override mail to:
  # 1. Guard against direct calls (must be called from ApplicationMailer or DeviseMailer)
  # 2. Set SES configuration based on email_category
  def mail(**args)
    caller_path = caller_locations(1, 1).first.path
    unless caller_path.end_with?('application_mailer.rb', 'devise_mailer.rb')
      raise "Use mail_to_user instead of mail directly in #{self.class.name}"
    end

    # Get config for this mailer's category
    config = EMAIL_CONFIGS.fetch(self.class.email_category) do
      raise "#{self.class.name} must set email_category to one of: #{EMAIL_CONFIGS.keys.join(', ')}"
    end

    # Set from address, SES configuration set, and reply-to
    args[:from] ||= config[:from_email]
    args[:reply_to] ||= Jiki.config.support_email
    headers['X-SES-CONFIGURATION-SET'] = config[:configuration_set]

    super
  end

  # Send email to a user with preference checking
  #
  # Checks both global email validity (bounce/complaint) and preference-specific opt-in.
  # Sets @user and @unsubscribe_key for use in templates (e.g., footer partial).
  #
  # @param user [User] The recipient user
  # @param unsubscribe_key [Symbol, nil] The preference key (e.g., :newsletters, :milestone_emails)
  #   If nil, only checks global email validity
  # @param args [Hash] Options passed to mail() (to:, subject:, etc.)
  # @return [Mail::Message, nil] The mail message, or nil if user shouldn't receive email
  def mail_to_user(user, unsubscribe_key: nil, **args, &block)
    return unless user.may_receive_emails?

    if unsubscribe_key
      return unless user.public_send("receive_#{unsubscribe_key}?")

      add_unsubscribe_headers!(user, unsubscribe_key)
    end

    # Set variables needed for rendering
    @user = user
    @unsubscribe_key = unsubscribe_key

    I18n.with_locale(user.locale) do
      mail(to: user.email, **args, &block)
    end
  end

  private
  # Convert markdown to HTML for email templates
  def markdown_to_html(markdown)
    Commonmarker.to_html(markdown).html_safe
  end

  # Convert markdown to plain text for email templates
  # Converts [text](url) to "text (url)"
  def markdown_to_text(markdown)
    # Convert markdown links [text](url) to "text (url)"
    markdown.gsub(/\[([^\]]+)\]\(([^)]+)\)/, '\1 (\2)')
  end

  # Generate unsubscribe URL for frontend
  def unsubscribe_url(token:, key: nil)
    url = "#{Jiki.config.frontend_base_url}/unsubscribe?token=#{token}"
    key.present? ? "#{url}&key=#{key}" : url
  end

  # Add RFC 8058 one-click unsubscribe headers
  def add_unsubscribe_headers!(user, unsubscribe_key)
    return unless user&.unsubscribe_token

    headers['List-Unsubscribe'] = "<#{unsubscribe_url(token: user.unsubscribe_token, key: unsubscribe_key)}>"
    headers['List-Unsubscribe-Post'] = 'List-Unsubscribe=One-Click'
  end
end
