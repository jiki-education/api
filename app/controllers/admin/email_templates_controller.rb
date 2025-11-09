class Admin::EmailTemplatesController < Admin::BaseController
  before_action :use_email_template, only: %i[show update destroy translate]

  def index
    email_templates = EmailTemplate::Search.(
      type: params[:type],
      slug: params[:slug],
      locale: params[:locale],
      page: params[:page],
      per: params[:per]
    )

    render json: SerializePaginatedCollection.(
      email_templates,
      serializer: SerializeAdminEmailTemplates
    )
  end

  def types
    render json: {
      types: EmailTemplate.types.keys
    }
  end

  def summary
    render json: {
      email_templates: EmailTemplate::GenerateSummary.(),
      locales: {
        supported: I18n::SUPPORTED_LOCALES,
        wip: I18n::WIP_LOCALES
      }
    }
  end

  def create
    email_template = EmailTemplate::Create.(email_template_params)
    render json: {
      email_template: SerializeAdminEmailTemplate.(email_template)
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e)
  end

  def show
    render json: {
      email_template: SerializeAdminEmailTemplate.(@email_template)
    }
  end

  def update
    email_template = EmailTemplate::Update.(@email_template, email_template_params)
    render json: {
      email_template: SerializeAdminEmailTemplate.(email_template)
    }
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e)
  end

  def destroy
    @email_template.destroy!
    head :no_content
  end

  def translate
    target_locales = EmailTemplate::TranslateToAllLocales.(@email_template)
    render json: {
      email_template: SerializeAdminEmailTemplate.(@email_template),
      queued_locales: target_locales
    }, status: :accepted
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private
  def use_email_template
    @email_template = EmailTemplate.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Email template not found")
  end

  def email_template_params
    params.require(:email_template).permit(:type, :slug, :locale, :subject, :body_mjml, :body_text)
  end
end
