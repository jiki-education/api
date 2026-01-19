require "test_helper"

class UserLevel::StartTest < ActiveSupport::TestCase
  test "creates user_level" do
    user = create(:user)
    level = create(:level)

    assert_difference -> { UserLevel.count }, 1 do
      UserLevel::Start.(user, level)
    end
  end

  test "returns created user_level" do
    user = create(:user)
    level = create(:level)

    result = UserLevel::Start.(user, level)

    assert_instance_of UserLevel, result
    assert_equal user.id, result.user_id
    assert_equal level.id, result.level_id
  end

  test "is idempotent - returns existing user_level on duplicate" do
    user = create(:user)
    level = create(:level)
    first_result = UserLevel::Start.(user, level)

    assert_no_difference -> { UserLevel.count } do
      second_result = UserLevel::Start.(user, level)
      assert_equal first_result.id, second_result.id
    end
  end

  test "allows same user to start different levels" do
    user = create(:user)
    level1 = create(:level)
    level2 = create(:level)

    result1 = UserLevel::Start.(user, level1)
    result2 = UserLevel::Start.(user, level2)

    refute_equal result1.id, result2.id
    assert_equal 2, user.user_levels.count
  end

  test "allows different users to start same level" do
    user1 = create(:user)
    user2 = create(:user)
    level = create(:level)

    result1 = UserLevel::Start.(user1, level)
    result2 = UserLevel::Start.(user2, level)

    refute_equal result1.id, result2.id
    assert_equal 2, level.user_levels.count
  end

  test "initializes with nil completed_at" do
    user = create(:user)
    level = create(:level)

    result = UserLevel::Start.(user, level)

    assert_nil result.completed_at
  end

  test "sets created_at on creation" do
    user = create(:user)
    level = create(:level)

    time_before = Time.current
    result = UserLevel::Start.(user, level)
    time_after = Time.current

    assert result.created_at >= time_before
    assert result.created_at <= time_after
  end

  test "updates user.current_user_level on first creation" do
    user = create(:user)
    level = create(:level)

    result = UserLevel::Start.(user, level)

    assert_equal result.id, user.reload.current_user_level_id
  end

  test "does not update user.current_user_level on subsequent calls" do
    user = create(:user)
    level = create(:level)
    first_user_level = UserLevel::Start.(user, level)

    # Verify tracking pointer was set on first call
    assert_equal first_user_level.id, user.reload.current_user_level_id

    # Call Start again (idempotent) - should return same user_level
    second_user_level = UserLevel::Start.(user, level)
    assert_equal first_user_level.id, second_user_level.id

    # Tracking pointer should remain unchanged (not re-set)
    assert_equal first_user_level.id, user.reload.current_user_level_id
  end

  # Lesson unlocked event tests
  test "emits lesson_unlocked event for first lesson when level is started" do
    user = create(:user)
    level = create(:level)
    create(:lesson, level:, slug: "first-lesson", position: 1)
    create(:lesson, level:, slug: "second-lesson", position: 2)

    Current.reset
    UserLevel::Start.(user, level)

    events = Current.events
    lesson_unlocked_events = events.select { |e| e[:type] == "lesson_unlocked" }
    assert_equal 1, lesson_unlocked_events.length
    assert_equal "first-lesson", lesson_unlocked_events.first[:data][:lesson_slug]
  end

  test "does not emit lesson_unlocked event when level has no lessons" do
    user = create(:user)
    level = create(:level)

    Current.reset
    UserLevel::Start.(user, level)

    events = Current.events || []
    lesson_unlocked_events = events.select { |e| e[:type] == "lesson_unlocked" }
    assert_equal 0, lesson_unlocked_events.length
  end

  test "does not emit lesson_unlocked event on subsequent calls (idempotent)" do
    user = create(:user)
    level = create(:level)
    create(:lesson, level:, slug: "first-lesson", position: 1)

    # First call - should emit event
    Current.reset
    UserLevel::Start.(user, level)
    events = Current.events
    assert_equal(1, events.count { |e| e[:type] == "lesson_unlocked" })

    # Second call - should not emit event (idempotent)
    Current.reset
    UserLevel::Start.(user, level)
    events = Current.events || []
    assert_equal(0, events.count { |e| e[:type] == "lesson_unlocked" })
  end
end
