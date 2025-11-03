require "test_helper"

class AssistantConversation::AddUserMessageTest < ActiveSupport::TestCase
  test "delegates to FindOrCreate and AddMessage" do
    user = create(:user)
    context_type = "Lesson"
    context_identifier = "basic-movement"
    content = "How do I solve this problem?"
    timestamp = "2025-10-31T08:15:30.000Z"

    conversation = build_stubbed(:assistant_conversation)
    AssistantConversation::FindOrCreate.expects(:call).with(user, context_type, context_identifier).returns(conversation)
    AssistantConversation::AddMessage.expects(:call).with(conversation, "user", content, timestamp)

    AssistantConversation::AddUserMessage.(user, context_type, context_identifier, content, timestamp)
  end
end
