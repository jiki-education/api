require "test_helper"

class Internal::AssistantConversationsControllerTest < ApplicationControllerTest
  setup do
    setup_user
    @lesson = create(:lesson, :exercise, slug: "basic-movement")
  end

  # Auth guards
  guard_incorrect_token! :internal_assistant_conversations_path, method: :post
  guard_incorrect_token! :user_messages_internal_assistant_conversations_path, method: :post
  guard_incorrect_token! :assistant_messages_internal_assistant_conversations_path, method: :post

  # POST create
  test "POST create returns conversation token for premium user" do
    @current_user.data.update!(membership_type: "premium")

    post internal_assistant_conversations_path,
      headers: @headers,
      params: { lesson_slug: "basic-movement" },
      as: :json

    assert_response :success
    assert response.parsed_body["token"].present?

    # Verify token is valid JWT
    payload = JWT.decode(
      response.parsed_body["token"],
      Jiki.secrets.jwt_secret,
      true,
      { algorithm: 'HS256' }
    ).first
    assert_equal @current_user.id, payload['sub']
    assert_equal "basic-movement", payload['lesson_slug']
  end

  test "POST create returns conversation token for standard user first lesson" do
    @current_user.data.update!(membership_type: "standard")

    post internal_assistant_conversations_path,
      headers: @headers,
      params: { lesson_slug: "basic-movement" },
      as: :json

    assert_response :success
    assert response.parsed_body["token"].present?
  end

  test "POST create returns 403 for standard user on different lesson" do
    @current_user.data.update!(membership_type: "standard")
    other_lesson = create(:lesson, :exercise, slug: "other-lesson")
    create(:assistant_conversation, user: @current_user, context: other_lesson)

    post internal_assistant_conversations_path,
      headers: @headers,
      params: { lesson_slug: "basic-movement" },
      as: :json

    assert_response :forbidden
    assert_equal "forbidden", response.parsed_body["error"]["type"]
    assert_equal "Assistant access not allowed for this lesson", response.parsed_body["error"]["message"]
  end

  test "POST create returns 404 for non-existent lesson" do
    post internal_assistant_conversations_path,
      headers: @headers,
      params: { lesson_slug: "non-existent" },
      as: :json

    assert_response :not_found
    assert_equal "not_found", response.parsed_body["error"]["type"]
  end

  test "POST create creates assistant conversation record" do
    @current_user.data.update!(membership_type: "premium")

    assert_difference 'AssistantConversation.count', 1 do
      post internal_assistant_conversations_path,
        headers: @headers,
        params: { lesson_slug: "basic-movement" },
        as: :json
    end

    conversation = AssistantConversation.last
    assert_equal @current_user, conversation.user
    assert_equal @lesson, conversation.context
  end

  # POST user_messages
  test "POST user_messages successfully adds user message" do
    post user_messages_internal_assistant_conversations_path,
      headers: @headers,
      params: {
        context_type: "lesson",
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
      @lesson,
      "How do I solve this?",
      "2025-10-31T08:15:30.000Z"
    ).returns(build_stubbed(:assistant_conversation))

    post user_messages_internal_assistant_conversations_path,
      headers: @headers,
      params: {
        context_type: "lesson",
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
        context_type: "lesson",
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
        context_type: "lesson",
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
      @lesson,
      content,
      timestamp,
      signature
    ).returns(build_stubbed(:assistant_conversation))

    post assistant_messages_internal_assistant_conversations_path,
      headers: @headers,
      params: {
        context_type: "lesson",
        context_identifier: "basic-movement",
        content:,
        timestamp:,
        signature:
      },
      as: :json

    assert_response :success
  end
end
