class Internal::AssistantConversationsController < Internal::BaseController
  include TurnstileVerifiable

  before_action :verify_turnstile!, only: %i[create]

  def create
    context = find_context
    return render_404(context_not_found_key) unless context

    token = AssistantConversation::CreateConversationToken.(current_user, context)
    render json: { token: }
  rescue AssistantConversationAccessDeniedError
    render_403(:access_denied)
  end

  def create_user_message
    context = Utils::RecordForIdentifier.(params[:context_type], params[:context_identifier])

    AssistantConversation::AddUserMessage.(
      current_user,
      context,
      params[:content],
      params[:timestamp]
    )

    render json: {}
  end

  def create_assistant_message
    context = Utils::RecordForIdentifier.(params[:context_type], params[:context_identifier])

    AssistantConversation::AddAssistantMessage.(
      current_user,
      context,
      params[:content],
      params[:timestamp],
      params[:signature]
    )

    render json: {}
  rescue InvalidHMACSignatureError
    render_401(:invalid_signature)
  end

  private
  def find_context
    if challenge_slug.present?
      Challenge.find_by(slug: challenge_slug)
    else
      Lesson.find_by(slug: params[:lesson_slug])
    end
  end

  # LEGACY: project_slug is the pre-rename param name. Delete the fallback
  # once the front end has been deployed.
  def challenge_slug = params[:challenge_slug].presence || params[:project_slug]

  def context_not_found_key
    return :challenge_not_found if params[:challenge_slug].present?
    return :project_not_found if params[:project_slug].present? # LEGACY: pre-rename param

    :lesson_not_found
  end
end
