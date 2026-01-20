require "test_helper"

class AssistantConversation::AddUserMessageTest < ActiveSupport::TestCase
  test "delegates to FindOrCreate and AddMessage" do
    user = create(:user)
    lesson = create(:lesson, :exercise, slug: "basic-movement")
    content = "How do I solve this problem?"
    timestamp = "2025-10-31T08:15:30.000Z"

    conversation = build_stubbed(:assistant_conversation)
    AssistantConversation::FindOrCreate.expects(:call).with(user, lesson).returns(conversation)
    AssistantConversation::AddMessage.expects(:call).with(conversation, "user", content, timestamp)

    AssistantConversation::AddUserMessage.(user, lesson, content, timestamp)
  end
end
