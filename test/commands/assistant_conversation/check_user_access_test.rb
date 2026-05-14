require "test_helper"

class AssistantConversation::CheckUserAccessTest < ActiveSupport::TestCase
  test "premium user is always allowed" do
    user = create(:user)
    user.data.update!(membership_type: "premium")
    lesson = create(:lesson, :exercise)

    assert AssistantConversation::CheckUserAccess.(user, lesson)
  end

  test "standard user with no previous conversation is allowed" do
    user = create(:user)
    user.data.update!(membership_type: "standard")
    lesson = create(:lesson, :exercise)

    assert AssistantConversation::CheckUserAccess.(user, lesson)
  end

  test "standard user accessing same lesson as most recent is allowed" do
    user = create(:user)
    user.data.update!(membership_type: "standard")
    lesson = create(:lesson, :exercise)
    create(:assistant_conversation, user:, context: lesson)

    assert AssistantConversation::CheckUserAccess.(user, lesson)
  end

  test "standard user accessing different lesson than most recent is denied" do
    user = create(:user)
    user.data.update!(membership_type: "standard")
    lesson1 = create(:lesson, :exercise)
    lesson2 = create(:lesson, :exercise)
    create(:assistant_conversation, user:, context: lesson1)

    refute AssistantConversation::CheckUserAccess.(user, lesson2)
  end

  test "standard user can switch to most recently updated lesson" do
    user = create(:user)
    user.data.update!(membership_type: "standard")
    lesson1 = create(:lesson, :exercise)
    lesson2 = create(:lesson, :exercise)

    # Create conversation for lesson1 first
    create(:assistant_conversation, user:, context: lesson1)

    # Create conversation for lesson2 later (more recent)
    travel 1.minute do
      create(:assistant_conversation, user:, context: lesson2)
    end

    # lesson2 is most recent, so lesson1 should be denied
    refute AssistantConversation::CheckUserAccess.(user, lesson1)

    # lesson2 should be allowed
    assert AssistantConversation::CheckUserAccess.(user, lesson2)
  end

  test "premium user is always allowed for project context" do
    user = create(:user)
    user.data.update!(membership_type: "premium")
    project = create(:project)

    assert AssistantConversation::CheckUserAccess.(user, project)
  end

  test "standard user with no previous conversation is allowed for project context" do
    user = create(:user)
    user.data.update!(membership_type: "standard")
    project = create(:project)

    assert AssistantConversation::CheckUserAccess.(user, project)
  end

  test "standard user with existing lesson conversation is denied for project context" do
    user = create(:user)
    user.data.update!(membership_type: "standard")
    lesson = create(:lesson, :exercise)
    project = create(:project)
    create(:assistant_conversation, user:, context: lesson)

    refute AssistantConversation::CheckUserAccess.(user, project)
  end

  test "standard user's project conversations do not consume the free lesson allowance" do
    user = create(:user)
    user.data.update!(membership_type: "standard")
    project = create(:project)
    lesson = create(:lesson, :exercise)
    create(:assistant_conversation, user:, context: project)

    # Project conversations are excluded from the free-lesson gate, so the
    # lesson is still allowed as the user's free one.
    assert AssistantConversation::CheckUserAccess.(user, lesson)
  end
end
