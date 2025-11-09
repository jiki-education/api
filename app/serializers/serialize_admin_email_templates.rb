class SerializeAdminEmailTemplates
  include Mandate

  initialize_with :email_templates

  def call
    email_templates.map do |email_template|
      {
        id: email_template.id,
        type: email_template.type,
        slug: email_template.slug,
        locale: email_template.locale
      }
    end
  end
end
