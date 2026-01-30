class ApplicationMailer < ActionMailer::Base
  layout "mailer"
  helper_method :unsubscribe_url

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
  # 1. Guard against direct calls (must use mail_to_user, unless DeviseMailer)
  # 2. Set SES configuration based on email_category
  def mail(called_via_mail_to_user: false, **args)
    unless called_via_mail_to_user || self.instance_of?(DeviseMailer)
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
      preference_method = "receive_#{unsubscribe_key}?"
      return unless user.public_send(preference_method)

      add_unsubscribe_headers!(user, unsubscribe_key)
    end

    # Set variables needed for rendering
    @user = user
    @unsubscribe_key = unsubscribe_key

    # Call the mail method with our special guard method that ensures this
    # doesn't get overriden accidently elsewhere.
    mail(**args, called_via_mail_to_user: true, &block)
  end

  # Sends an email using a database-backed email template with Liquid rendering
  #
  # Automatically injects the user into the Liquid context and handles all template
  # rendering, MJML compilation, and multipart (HTML/text) mail delivery.
  #
  # @param user [User] The recipient user (also injected into Liquid context)
  # @param template_type [Symbol] The type of template (e.g., :level_completion)
  # @param template_key [String] The template key (e.g., level slug)
  # @param unsubscribe_key [Symbol, nil] The preference key for unsubscribe
  # @param context [Hash] Additional context for Liquid rendering (keys as symbols)
  #
  # @return [Mail::Message, nil] The mail message if template found, nil otherwise
  def mail_template_to_user(user, template_type, template_key, unsubscribe_key: nil, context: {})
    # Find the template for this type, key, and user's locale
    template = EmailTemplate.find_for(template_type, template_key, user.locale)
    return unless template

    # Build Liquid context with user automatically included
    liquid_context = { 'user' => UserDrop.new(user) }

    # Merge in provided context, converting symbol keys to strings for Liquid
    context.each do |key, value|
      liquid_context[key.to_s] = value
    end

    # Render subject with Liquid
    subject = Liquid::Template.parse(template.subject).render(liquid_context)

    # Render MJML body content with Liquid (content only, no layout wrapper)
    @mjml_content = Liquid::Template.parse(template.body_mjml).render(liquid_context).html_safe

    # Render text body with Liquid
    text_body = Liquid::Template.parse(template.body_text).render(liquid_context)

    # Send email in user's locale with multipart HTML/text
    with_locale(user) do
      mail_to_user(user, unsubscribe_key:, to: user.email, subject:) do |format|
        format.html { render inline: @mjml_content, layout: 'mailer' }
        format.text { render plain: text_body }
      end
    end
  end

  # Set the locale for the email based on the recipient's preference
  def with_locale(user, &block)
    I18n.with_locale(user.locale || I18n.default_locale, &block)
  end

  private
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
