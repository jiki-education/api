require "test_helper"

class AssistantConversation::FindOrCreateTest < ActiveSupport::TestCase
  test "creates new conversation if none exists" do
    user = create(:user)
    lesson = create(:lesson, :exercise, slug: "basic-movement")

    assert_difference 'AssistantConversation.count', 1 do
      conversation = AssistantConversation::FindOrCreate.(user, lesson)

      assert_equal user, conversation.user
      assert_equal lesson, conversation.context
      assert_equal "Lesson", conversation.context_type
      assert_equal lesson.id, conversation.context_id
      assert_empty conversation.messages
    end
  end

  test "finds existing conversation" do
    user = create(:user)
    lesson = create(:lesson, :exercise, slug: "basic-movement")
    existing_conversation = create(:assistant_conversation, user:, context: lesson)

    assert_no_difference 'AssistantConversation.count' do
      conversation = AssistantConversation::FindOrCreate.(user, lesson)

      assert_equal existing_conversation.id, conversation.id
      assert_equal user, conversation.user
      assert_equal lesson, conversation.context
    end
  end

  test "enforces uniqueness constraint" do
    user = create(:user)
    lesson = create(:lesson, :exercise, slug: "basic-movement")

    create(:assistant_conversation, user:, context: lesson)

    # Trying to create another with same attributes should find the existing one
    assert_no_difference 'AssistantConversation.count' do
      AssistantConversation::FindOrCreate.(user, lesson)
    end
  end

  test "defers assistant_conversation_started event on new conversation" do
    user = create(:user)
    lesson = create(:lesson, :exercise, slug: "basic-movement")

    Analytics::TrackEvent.expects(:defer).with(
      user,
      "assistant_conversation_started",
      properties: {
        context_type: "lesson",
        context_id: lesson.id,
        context_slug: "basic-movement",
        trial: true
      }
    )

    AssistantConversation::FindOrCreate.(user, lesson)
  end

  test "sets trial to false for premium users" do
    user = create(:user)
    make_premium(user)
    lesson = create(:lesson, :exercise, slug: "basic-movement")

    Analytics::TrackEvent.expects(:defer).with(
      user,
      "assistant_conversation_started",
      properties: {
        context_type: "lesson",
        context_id: lesson.id,
        context_slug: "basic-movement",
        trial: false
      }
    )

    AssistantConversation::FindOrCreate.(user, lesson)
  end

  test "does not fire event when finding existing conversation" do
    user = create(:user)
    lesson = create(:lesson, :exercise, slug: "basic-movement")
    create(:assistant_conversation, user:, context: lesson)

    Analytics::TrackEvent.expects(:defer).never

    AssistantConversation::FindOrCreate.(user, lesson)
  end
end
