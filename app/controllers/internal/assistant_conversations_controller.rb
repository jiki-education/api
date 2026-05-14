class Internal::AssistantConversationsController < Internal::BaseController
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
    if params[:project_slug].present?
      Project.find_by(slug: params[:project_slug])
    else
      Lesson.find_by(slug: params[:lesson_slug])
    end
  end

  def context_not_found_key
    params[:project_slug].present? ? :project_not_found : :lesson_not_found
  end
end
