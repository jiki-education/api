class Internal::AssistantConversationsController < Internal::BaseController
  def create_user_message
    AssistantConversation::AddUserMessage.(
      current_user,
      params[:context_type],
      params[:context_identifier],
      params[:content],
      params[:timestamp]
    )

    render json: {}
  end

  def create_assistant_message
    AssistantConversation::AddAssistantMessage.(
      current_user,
      params[:context_type],
      params[:context_identifier],
      params[:content],
      params[:timestamp],
      params[:signature]
    )

    render json: {}
  rescue InvalidHMACSignatureError
    render json: { error: 'Invalid signature' }, status: :unauthorized
  end
end
