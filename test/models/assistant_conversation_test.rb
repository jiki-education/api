require "test_helper"

class AssistantConversationTest < ActiveSupport::TestCase
  test "belongs_to user" do
    user = create(:user)
    conversation = create(:assistant_conversation, user:)

    assert_equal user, conversation.user
  end

  test "validates presence of context_type" do
    conversation = build(:assistant_conversation, context_type: nil)

    refute conversation.valid?
    assert_includes conversation.errors[:context_type], "can't be blank"
  end

  test "validates presence of context_identifier" do
    conversation = build(:assistant_conversation, context_identifier: nil)

    refute conversation.valid?
    assert_includes conversation.errors[:context_identifier], "can't be blank"
  end

  test "messages defaults to empty array" do
    conversation = AssistantConversation.new

    assert_empty conversation.messages
  end

  test "enforces unique index on user_id, context_type, context_identifier" do
    user = create(:user)
    create(:assistant_conversation, user:, context_type: "Lesson", context_identifier: "test-lesson")

    error = assert_raises ActiveRecord::RecordNotUnique do
      create(:assistant_conversation, user:, context_type: "Lesson", context_identifier: "test-lesson")
    end

    assert_match(/index_assistant_conversations_on_user_and_context/, error.message)
  end
end
