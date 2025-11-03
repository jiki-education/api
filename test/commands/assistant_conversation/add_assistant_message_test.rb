require "test_helper"

class AssistantConversation::AddAssistantMessageTest < ActiveSupport::TestCase
  test "delegates to VerifyHMAC, FindOrCreate and AddMessage" do
    user = create(:user)
    context_type = "Lesson"
    context_identifier = "basic-movement"
    content = "Try breaking it down step by step."
    timestamp = "2025-10-31T08:15:35.000Z"
    signature = "test_signature"

    conversation = build_stubbed(:assistant_conversation)

    AssistantConversation::VerifyHMAC.expects(:call).with(
      user.id,
      content,
      timestamp,
      signature
    ).returns(true)

    AssistantConversation::FindOrCreate.expects(:call).with(user, context_type, context_identifier).returns(conversation)
    AssistantConversation::AddMessage.expects(:call).with(conversation, "assistant", content, timestamp)

    AssistantConversation::AddAssistantMessage.(
      user,
      context_type,
      context_identifier,
      content,
      timestamp,
      signature
    )
  end

  test "raises InvalidHMACSignatureError with invalid signature" do
    user = create(:user)
    context_type = "Lesson"
    context_identifier = "basic-movement"
    content = "Try breaking it down step by step."
    timestamp = "2025-10-31T08:15:35.000Z"
    invalid_signature = "invalid_signature"

    error = assert_raises InvalidHMACSignatureError do
      AssistantConversation::AddAssistantMessage.(
        user,
        context_type,
        context_identifier,
        content,
        timestamp,
        invalid_signature
      )
    end

    assert_match(/HMAC signature verification failed/, error.message)
  end
end
