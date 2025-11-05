class Internal::AssistantConversationsController < Internal::BaseController
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
    render json: { error: 'Invalid signature' }, status: :unauthorized
  end
end
