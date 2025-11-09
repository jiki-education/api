class SerializeAdminEmailTemplate
  include Mandate

  initialize_with :email_template

  def call
    {
      id: email_template.id,
      type: email_template.type,
      slug: email_template.slug,
      locale: email_template.locale,
      subject: email_template.subject,
      body_mjml: email_template.body_mjml,
      body_text: email_template.body_text
    }
  end
end
