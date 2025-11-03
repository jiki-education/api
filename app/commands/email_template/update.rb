class EmailTemplate::Update
  include Mandate

  initialize_with :email_template, :params

  def call
    email_template.update!(filtered_params)
    email_template
  end

  private
  def filtered_params
    params.slice(:type, :slug, :locale, :subject, :body_mjml, :body_text)
  end
end
