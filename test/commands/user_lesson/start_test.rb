require "test_helper"

class UserLesson::StartTest < ActiveSupport::TestCase
  test "creates user_lesson when level exists" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)
    create(:user_level, user:, level:)

    assert_difference -> { UserLesson.count }, 1 do
      UserLesson::Start.(user, lesson)
    end
  end

  test "returns created user_lesson" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)
    create(:user_level, user:, level:)

    result = UserLesson::Start.(user, lesson)

    assert_instance_of UserLesson, result
    assert_equal user.id, result.user_id
    assert_equal lesson.id, result.lesson_id
  end

  test "is idempotent - returns existing user_lesson on duplicate" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)
    create(:user_level, user:, level:)
    first_result = UserLesson::Start.(user, lesson)

    assert_no_difference -> { UserLesson.count } do
      second_result = UserLesson::Start.(user, lesson)
      assert_equal first_result.id, second_result.id
    end
  end

  test "raises UserLevelNotFoundError when user_level doesn't exist" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)

    error = assert_raises(UserLevelNotFoundError) do
      UserLesson::Start.(user, lesson)
    end

    assert_equal "Level not available", error.message
  end

  test "raises LessonInProgressError when lesson is in progress" do
    user = create(:user)
    level = create(:level)
    lesson1 = create(:lesson, level:)
    lesson2 = create(:lesson, level:)
    user_level = create(:user_level, user:, level:)
    in_progress_lesson = create(:user_lesson, user:, lesson: lesson1, completed_at: nil)
    user_level.update!(current_user_lesson: in_progress_lesson)

    error = assert_raises(LessonInProgressError) do
      UserLesson::Start.(user, lesson2)
    end

    assert_equal "Complete current lesson before starting a new one", error.message
  end

  test "allows starting new lesson when previous is completed" do
    user = create(:user)
    level = create(:level)
    lesson1 = create(:lesson, level:)
    lesson2 = create(:lesson, level:)
    user_level = create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson: lesson1, completed_at: Time.current)
    user_level.update!(current_user_lesson: nil)

    assert_nothing_raised do
      UserLesson::Start.(user, lesson2)
    end
  end

  test "raises LevelNotCompletedError when trying to start lesson in next level" do
    user = create(:user)
    level1 = create(:level)
    level2 = create(:level)
    lesson1 = create(:lesson, level: level1)
    lesson2 = create(:lesson, level: level2)
    user_level1 = create(:user_level, user:, level: level1)
    user.update!(current_user_level: user_level1)
    create(:user_lesson, user:, lesson: lesson1, completed_at: Time.current)
    create(:user_level, user:, level: level2)

    error = assert_raises(LevelNotCompletedError) do
      UserLesson::Start.(user, lesson2)
    end

    assert_equal "Complete the current level before starting lessons in the next level", error.message
  end

  test "allows starting lesson in current level" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)
    user_level = create(:user_level, user:, level:)
    user.update!(current_user_level: user_level)

    assert_nothing_raised do
      UserLesson::Start.(user, lesson)
    end
  end

  test "updates user_level.current_user_lesson on first creation" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)
    user_level = create(:user_level, user:, level:)

    result = UserLesson::Start.(user, lesson)

    assert_equal result.id, user_level.reload.current_user_lesson_id
  end

  test "updates user.current_user_level on first creation" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)
    user_level = create(:user_level, user:, level:)

    UserLesson::Start.(user, lesson)

    assert_equal user_level.id, user.reload.current_user_level_id
  end

  test "does not update tracking pointers on subsequent calls" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)
    user_level = create(:user_level, user:, level:)
    first_user_lesson = UserLesson::Start.(user, lesson)

    # Verify tracking pointers were set on first call
    assert_equal first_user_lesson.id, user_level.reload.current_user_lesson_id
    assert_equal user_level.id, user.reload.current_user_level_id

    # Call Start again (idempotent) - should return same user_lesson
    second_user_lesson = UserLesson::Start.(user, lesson)
    assert_equal first_user_lesson.id, second_user_lesson.id

    # Tracking pointers should remain unchanged (not re-set)
    assert_equal first_user_lesson.id, user_level.reload.current_user_lesson_id
    assert_equal user_level.id, user.reload.current_user_level_id
  end

  test "initializes with nil completed_at" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)
    create(:user_level, user:, level:)

    result = UserLesson::Start.(user, lesson)

    assert_nil result.completed_at
  end

  test "sets created_at on creation" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)
    create(:user_level, user:, level:)

    time_before = Time.current
    result = UserLesson::Start.(user, lesson)
    time_after = Time.current

    assert result.created_at >= time_before
    assert result.created_at <= time_after
  end
end
