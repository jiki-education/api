class EmailTemplate::Create
  include Mandate

  initialize_with :params

  def call
    EmailTemplate.create!(filtered_params)
  end

  private
  def filtered_params
    params.slice(:type, :slug, :locale, :subject, :body_mjml, :body_text)
  end
end
