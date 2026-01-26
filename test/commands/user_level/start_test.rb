require "test_helper"

class UserLevel::StartTest < ActiveSupport::TestCase
  test "creates user_level" do
    user_course = create(:user_course)
    level = create(:level, course: user_course.course)

    assert_difference -> { UserLevel.count }, 1 do
      UserLevel::Start.(user_course.user, level)
    end
  end

  test "returns created user_level" do
    user_course = create(:user_course)
    level = create(:level, course: user_course.course)

    result = UserLevel::Start.(user_course.user, level)

    assert_instance_of UserLevel, result
    assert_equal user_course.user_id, result.user_id
    assert_equal level.id, result.level_id
    assert_equal user_course.course_id, result.course_id
  end

  test "is idempotent - returns existing user_level on duplicate" do
    user_course = create(:user_course)
    level = create(:level, course: user_course.course)
    first_result = UserLevel::Start.(user_course.user, level)

    assert_no_difference -> { UserLevel.count } do
      second_result = UserLevel::Start.(user_course.user, level)
      assert_equal first_result.id, second_result.id
    end
  end

  test "allows same user to start different levels in same course" do
    user_course = create(:user_course)
    level1 = create(:level, course: user_course.course, position: 1)
    level2 = create(:level, course: user_course.course, position: 2)

    result1 = UserLevel::Start.(user_course.user, level1)
    result2 = UserLevel::Start.(user_course.user, level2)

    refute_equal result1.id, result2.id
    assert_equal 2, user_course.user.user_levels.count
  end

  test "allows different users to start same level" do
    level = create(:level)
    user_course1 = create(:user_course, course: level.course)
    user_course2 = create(:user_course, course: level.course)

    result1 = UserLevel::Start.(user_course1.user, level)
    result2 = UserLevel::Start.(user_course2.user, level)

    refute_equal result1.id, result2.id
    assert_equal 2, level.user_levels.count
  end

  test "initializes with nil completed_at" do
    user_course = create(:user_course)
    level = create(:level, course: user_course.course)

    result = UserLevel::Start.(user_course.user, level)

    assert_nil result.completed_at
  end

  test "sets created_at on creation" do
    user_course = create(:user_course)
    level = create(:level, course: user_course.course)

    time_before = Time.current
    result = UserLevel::Start.(user_course.user, level)
    time_after = Time.current

    assert result.created_at >= time_before
    assert result.created_at <= time_after
  end

  test "updates user_course.current_user_level on first creation" do
    user_course = create(:user_course)
    level = create(:level, course: user_course.course)

    result = UserLevel::Start.(user_course.user, level)

    assert_equal result.id, user_course.reload.current_user_level_id
  end

  test "does not update user_course.current_user_level on subsequent calls" do
    user_course = create(:user_course)
    level = create(:level, course: user_course.course)
    first_user_level = UserLevel::Start.(user_course.user, level)

    assert_equal first_user_level.id, user_course.reload.current_user_level_id

    second_user_level = UserLevel::Start.(user_course.user, level)
    assert_equal first_user_level.id, second_user_level.id
    assert_equal first_user_level.id, user_course.reload.current_user_level_id
  end

  test "emits lesson_unlocked event for first lesson when level is started" do
    user_course = create(:user_course)
    level = create(:level, course: user_course.course)
    create(:lesson, :exercise, level:, slug: "first-lesson", position: 1)
    create(:lesson, :exercise, level:, slug: "second-lesson", position: 2)

    Current.reset
    UserLevel::Start.(user_course.user, level)

    events = Current.events
    lesson_unlocked_events = events.select { |e| e[:type] == "lesson_unlocked" }
    assert_equal 1, lesson_unlocked_events.length
    assert_equal "first-lesson", lesson_unlocked_events.first[:data][:lesson_slug]
  end

  test "does not emit lesson_unlocked event when level has no lessons" do
    user_course = create(:user_course)
    level = create(:level, course: user_course.course)

    Current.reset
    UserLevel::Start.(user_course.user, level)

    events = Current.events || []
    lesson_unlocked_events = events.select { |e| e[:type] == "lesson_unlocked" }
    assert_equal 0, lesson_unlocked_events.length
  end

  test "does not emit lesson_unlocked event on subsequent calls (idempotent)" do
    user_course = create(:user_course)
    level = create(:level, course: user_course.course)
    create(:lesson, :exercise, level:, slug: "first-lesson", position: 1)

    Current.reset
    UserLevel::Start.(user_course.user, level)
    events = Current.events
    assert_equal(1, events.count { |e| e[:type] == "lesson_unlocked" })

    Current.reset
    UserLevel::Start.(user_course.user, level)
    events = Current.events || []
    assert_equal(0, events.count { |e| e[:type] == "lesson_unlocked" })
  end
end
