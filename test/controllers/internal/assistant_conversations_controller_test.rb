require "test_helper"

class Internal::AssistantConversationsControllerTest < ApplicationControllerTest
  setup do
    setup_user
  end

  # Auth guards
  guard_incorrect_token! :user_messages_internal_assistant_conversations_path, method: :post
  guard_incorrect_token! :assistant_messages_internal_assistant_conversations_path, method: :post

  # POST user_messages
  test "POST user_messages successfully adds user message" do
    post user_messages_internal_assistant_conversations_path,
      headers: @headers,
      params: {
        context_type: "Lesson",
        context_identifier: "basic-movement",
        content: "How do I solve this?",
        timestamp: "2025-10-31T08:15:30.000Z"
      },
      as: :json

    assert_response :success
    assert_json_response({})
  end

  test "POST user_messages delegates to AddUserMessage command" do
    AssistantConversation::AddUserMessage.expects(:call).with(
      @current_user,
      "Lesson",
      "basic-movement",
      "How do I solve this?",
      "2025-10-31T08:15:30.000Z"
    ).returns(build_stubbed(:assistant_conversation))

    post user_messages_internal_assistant_conversations_path,
      headers: @headers,
      params: {
        context_type: "Lesson",
        context_identifier: "basic-movement",
        content: "How do I solve this?",
        timestamp: "2025-10-31T08:15:30.000Z"
      },
      as: :json

    assert_response :success
  end

  # POST assistant_messages
  test "POST assistant_messages successfully adds assistant message with valid signature" do
    content = "Try breaking it down step by step."
    timestamp = "2025-10-31T08:15:35.000Z"
    payload = "#{@current_user.id}:#{content}:#{timestamp}"
    signature = OpenSSL::HMAC.hexdigest('SHA256', Jiki.secrets.hmac_secret, payload)

    post assistant_messages_internal_assistant_conversations_path,
      headers: @headers,
      params: {
        context_type: "Lesson",
        context_identifier: "basic-movement",
        content:,
        timestamp:,
        signature:
      },
      as: :json

    assert_response :success
    assert_json_response({})
  end

  test "POST assistant_messages with invalid signature returns 401" do
    post assistant_messages_internal_assistant_conversations_path,
      headers: @headers,
      params: {
        context_type: "Lesson",
        context_identifier: "basic-movement",
        content: "Try breaking it down step by step.",
        timestamp: "2025-10-31T08:15:35.000Z",
        signature: "invalid_signature"
      },
      as: :json

    assert_response :unauthorized
    assert_equal "Invalid signature", response.parsed_body["error"]
  end

  test "POST assistant_messages delegates to AddAssistantMessage command" do
    content = "Try breaking it down step by step."
    timestamp = "2025-10-31T08:15:35.000Z"
    payload = "#{@current_user.id}:#{content}:#{timestamp}"
    signature = OpenSSL::HMAC.hexdigest('SHA256', Jiki.secrets.hmac_secret, payload)

    AssistantConversation::AddAssistantMessage.expects(:call).with(
      @current_user,
      "Lesson",
      "basic-movement",
      content,
      timestamp,
      signature
    ).returns(build_stubbed(:assistant_conversation))

    post assistant_messages_internal_assistant_conversations_path,
      headers: @headers,
      params: {
        context_type: "Lesson",
        context_identifier: "basic-movement",
        content:,
        timestamp:,
        signature:
      },
      as: :json

    assert_response :success
  end
end
