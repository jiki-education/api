require "test_helper"

class AssistantConversation::AddMessageTest < ActiveSupport::TestCase
  test "adds message to conversation and saves" do
    conversation = create(:assistant_conversation)
    role = "user"
    content = "How do I solve this?"
    timestamp = "2025-10-31T08:15:30.000Z"

    AssistantConversation::AddMessage.(conversation, role, content, timestamp)

    conversation.reload
    assert_equal 1, conversation.messages.length

    message = conversation.messages.first
    assert_equal role, message["role"]
    assert_equal content, message["content"]
    assert_equal timestamp, message["timestamp"]
  end

  test "appends to existing messages" do
    existing_messages = [
      {
        "role" => "user",
        "content" => "First message",
        "timestamp" => "2025-10-31T08:15:00.000Z"
      }
    ]
    conversation = create(:assistant_conversation, messages: existing_messages)

    role = "assistant"
    content = "Second message"
    timestamp = "2025-10-31T08:15:30.000Z"

    AssistantConversation::AddMessage.(conversation, role, content, timestamp)

    conversation.reload
    assert_equal 2, conversation.messages.length

    new_message = conversation.messages.last
    assert_equal role, new_message["role"]
    assert_equal content, new_message["content"]
    assert_equal timestamp, new_message["timestamp"]
  end

  test "locks the row during update" do
    conversation = create(:assistant_conversation)

    # Verify with_lock is called
    AssistantConversation.any_instance.expects(:with_lock).yields

    AssistantConversation::AddMessage.(
      conversation,
      "user",
      "Test message",
      "2025-10-31T08:15:30.000Z"
    )
  end
end
