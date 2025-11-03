require "test_helper"

class AssistantConversation::FindOrCreateTest < ActiveSupport::TestCase
  test "creates new conversation if none exists" do
    user = create(:user)
    context_type = "Lesson"
    context_identifier = "basic-movement"

    assert_difference 'AssistantConversation.count', 1 do
      conversation = AssistantConversation::FindOrCreate.(user, context_type, context_identifier)

      assert_equal user, conversation.user
      assert_equal context_type, conversation.context_type
      assert_equal context_identifier, conversation.context_identifier
      assert_empty conversation.messages
    end
  end

  test "finds existing conversation" do
    user = create(:user)
    context_type = "Lesson"
    context_identifier = "basic-movement"
    existing_conversation = create(
      :assistant_conversation,
      user:,
      context_type:,
      context_identifier:
    )

    assert_no_difference 'AssistantConversation.count' do
      conversation = AssistantConversation::FindOrCreate.(user, context_type, context_identifier)

      assert_equal existing_conversation.id, conversation.id
      assert_equal user, conversation.user
      assert_equal context_type, conversation.context_type
      assert_equal context_identifier, conversation.context_identifier
    end
  end

  test "enforces uniqueness constraint" do
    user = create(:user)
    context_type = "Lesson"
    context_identifier = "basic-movement"

    create(:assistant_conversation, user:, context_type:, context_identifier:)

    # Trying to create another with same attributes should find the existing one
    assert_no_difference 'AssistantConversation.count' do
      AssistantConversation::FindOrCreate.(user, context_type, context_identifier)
    end
  end
end
