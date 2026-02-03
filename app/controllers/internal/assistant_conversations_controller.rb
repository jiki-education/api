class Internal::AssistantConversationsController < Internal::BaseController
  def create
    lesson = Lesson.find_by(slug: params[:lesson_slug])
    return render_404(:lesson_not_found) unless lesson

    token = AssistantConversation::CreateConversationToken.(current_user, lesson)
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
end
