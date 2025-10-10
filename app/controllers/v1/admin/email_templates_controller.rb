class V1::Admin::EmailTemplatesController < V1::Admin::BaseController
  before_action :set_email_template, only: %i[show update destroy]

  def index
    email_templates = EmailTemplate.all
    render json: {
      email_templates: SerializeEmailTemplates.(email_templates)
    }
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
      email_template: SerializeEmailTemplate.(email_template)
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      error: {
        type: "validation_error",
        message: e.message
      }
    }, status: :unprocessable_entity
  end

  def show
    render json: {
      email_template: SerializeEmailTemplate.(@email_template)
    }
  end

  def update
    email_template = EmailTemplate::Update.(@email_template, email_template_params)
    render json: {
      email_template: SerializeEmailTemplate.(email_template)
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      error: {
        type: "validation_error",
        message: e.message
      }
    }, status: :unprocessable_entity
  end

  def destroy
    @email_template.destroy!
    head :no_content
  end

  private
  def set_email_template
    @email_template = EmailTemplate.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: {
        type: "not_found",
        message: "Email template not found"
      }
    }, status: :not_found
  end

  def email_template_params
    params.require(:email_template).permit(:type, :slug, :locale, :subject, :body_mjml, :body_text)
  end
end
