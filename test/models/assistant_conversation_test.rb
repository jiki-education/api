require "test_helper"

class AssistantConversationTest < ActiveSupport::TestCase
  test "belongs_to user" do
    user = create(:user)
    conversation = create(:assistant_conversation, user:)

    assert_equal user, conversation.user
  end

  test "belongs_to context polymorphically" do
    user = create(:user)
    lesson = create(:lesson)
    conversation = create(:assistant_conversation, user:, context: lesson)

    assert_equal lesson, conversation.context
    assert_equal "Lesson", conversation.context_type
    assert_equal lesson.id, conversation.context_id
  end

  test "messages defaults to empty array" do
    conversation = AssistantConversation.new

    assert_empty conversation.messages
  end

  test "enforces unique index on user_id, context_type, context_id" do
    user = create(:user)
    lesson = create(:lesson)
    create(:assistant_conversation, user:, context: lesson)

    error = assert_raises ActiveRecord::RecordNotUnique do
      create(:assistant_conversation, user:, context: lesson)
    end

    assert_match(/index_assistant_conversations_on_user_and_context/, error.message)
  end
end
