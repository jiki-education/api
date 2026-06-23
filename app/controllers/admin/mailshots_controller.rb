class Admin::MailshotsController < Admin::BaseController
  before_action :use_mailshot, only: %i[show update destroy preview send_test send_to_segment]

  def index
    mailshots = Mailshot.order(created_at: :desc).page(params[:page]).per(params[:per])

    render json: SerializePaginatedCollection.(
      mailshots,
      serializer: SerializeMailshots
    )
  end

  def show
    render json: { mailshot: SerializeMailshot.(@mailshot) }
  end

  def create
    mailshot = Mailshot.create!(mailshot_params)
    render json: { mailshot: SerializeMailshot.(mailshot) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_422(:validation_error, errors: e.record.errors.as_json)
  end

  def update
    @mailshot.update!(mailshot_params)
    render json: { mailshot: SerializeMailshot.(@mailshot) }
  rescue ActiveRecord::RecordInvalid => e
    render_422(:validation_error, errors: e.record.errors.as_json)
  end

  def destroy
    return render_422(:mailshot_already_sent) if @mailshot.sent?

    @mailshot.destroy!
    head :no_content
  end

  def preview
    @mailshot.assign_attributes(preview_params)
    render json: { html: Mailshot::RenderPreview.(@mailshot, current_user) }
  end

  def send_test
    Mailshot::SendTestEmail.(@mailshot, current_user)
    render json: { success: true }
  end

  def send_to_segment
    # A re-send of an already-sent segment is a no-op, so report 0 queued.
    already_sent = @mailshot.sent_to_audience?(params[:segment])
    Mailshot::Send.(@mailshot, params[:segment])
    audience_count = already_sent ? 0 : @mailshot.segment_relation(params[:segment]).count

    render json: {
      mailshot: SerializeMailshot.(@mailshot.reload),
      audience_count:
    }
  rescue MailshotUnknownSegmentError
    render_422(:unknown_segment, segment: params[:segment])
  rescue MailshotBlankBodyError
    render_422(:mailshot_body_blank)
  end

  private
  def use_mailshot
    @mailshot = Mailshot.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404(:mailshot_not_found)
  end

  def mailshot_params
    params.require(:mailshot).permit(:slug, :subject, :body_markdown, :email_communication_preferences_key)
  end

  def preview_params
    params.require(:mailshot).permit(:subject, :body_markdown)
  end
end
