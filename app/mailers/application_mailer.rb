class ApplicationMailer < ActionMailer::Base
  default from: -> { default_from_email }
  layout "mailer"

  private
  # Override in subclasses to specify different from email
  def default_from_email
    Jiki.config.respond_to?(:mail_from_email) ? Jiki.config.mail_from_email : "hello@jiki.io"
  end

  # Override in subclasses to specify SES configuration set
  def configuration_set
    Jiki.config.ses_mail_configuration_set if Jiki.config.respond_to?(:ses_mail_configuration_set)
  end

  # Override in subclasses to customize reply-to
  def reply_to_email
    Jiki.config.support_email if Jiki.config.respond_to?(:support_email)
  end

  # Add SES configuration set header to all emails
  # This enables tracking, dedicated IP routing, and event notifications
  def mail(**args)
    # Set SES configuration set for tracking and dedicated IP routing
    headers['X-SES-CONFIGURATION-SET'] = configuration_set if configuration_set

    # Set reply-to if different from from address
    args[:reply_to] ||= reply_to_email if reply_to_email

    super(**args)
  end

  # Sends an email using a database-backed email template with Liquid rendering
  #
  # Automatically injects the user into the Liquid context and handles all template
  # rendering, MJML compilation, and multipart (HTML/text) mail delivery.
  #
  # @param user [User] The recipient user (also injected into Liquid context)
  # @param template_type [Symbol] The type of template (e.g., :level_completion)
  # @param template_key [String] The template key (e.g., level slug)
  # @param context [Hash] Additional context for Liquid rendering (keys as symbols)
  #
  # @example
  #   mail_template_with_locale(
  #     user,
  #     :level_completion,
  #     level.slug,
  #     { level: LevelDrop.new(level) }
  #   )
  #
  # @return [Mail::Message, nil] The mail message if template found, nil otherwise
  def mail_template_with_locale(user, template_type, template_key, context = {})
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
    # Content is already in MJML format (<mj-section> tags), not HAML
    @mjml_content = Liquid::Template.parse(template.body_mjml).render(liquid_context).html_safe

    # Render text body with Liquid
    text_body = Liquid::Template.parse(template.body_text).render(liquid_context)

    # Send email in user's locale with multipart HTML/text
    # The layout will wrap @mjml_content and compile it via MJML/MRML
    with_locale(user) do
      mail(to: user.email, subject:) do |format|
        format.html { render inline: @mjml_content, layout: 'mailer' }
        format.text { render plain: text_body }
      end
    end
  end

  # Set the locale for the email based on the recipient's preference
  # Usage in subclasses:
  #   def welcome_email(user)
  #     with_locale(user) do
  #       mail(to: user.email, subject: t('.subject'))
  #     end
  #   end
  def with_locale(user, &)
    I18n.with_locale(user.locale || I18n.default_locale, &)
  end
end
