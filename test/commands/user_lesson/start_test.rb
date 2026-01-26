require "test_helper"

class UserLesson::StartTest < ActiveSupport::TestCase
  test "creates user_lesson when level exists" do
    user_level = create(:user_level)
    lesson = create(:lesson, :exercise, level: user_level.level)

    assert_difference -> { UserLesson.count }, 1 do
      UserLesson::Start.(user_level.user, lesson)
    end
  end

  test "returns created user_lesson" do
    user_level = create(:user_level)
    lesson = create(:lesson, :exercise, level: user_level.level)

    result = UserLesson::Start.(user_level.user, lesson)

    assert_instance_of UserLesson, result
    assert_equal user_level.user_id, result.user_id
    assert_equal lesson.id, result.lesson_id
    assert_equal user_level.course, result.course
  end

  test "is idempotent - returns existing user_lesson on duplicate" do
    user_level = create(:user_level)
    lesson = create(:lesson, :exercise, level: user_level.level)
    first_result = UserLesson::Start.(user_level.user, lesson)

    assert_no_difference -> { UserLesson.count } do
      second_result = UserLesson::Start.(user_level.user, lesson)
      assert_equal first_result.id, second_result.id
    end
  end

  test "raises UserLevelNotFoundError when not enrolled in course" do
    user = create(:user)
    lesson = create(:lesson, :exercise)

    error = assert_raises(UserLevelNotFoundError) do
      UserLesson::Start.(user, lesson)
    end

    assert_equal "Level not available", error.message
  end

  test "raises UserLevelNotFoundError when user_level doesn't exist" do
    lesson = create(:lesson, :exercise)
    user_course = create(:user_course, course: lesson.level.course)

    error = assert_raises(UserLevelNotFoundError) do
      UserLesson::Start.(user_course.user, lesson)
    end

    assert_equal "Level not available", error.message
  end

  test "raises LessonInProgressError when lesson is in progress" do
    user_level = create(:user_level)
    lesson1 = create(:lesson, :exercise, level: user_level.level)
    lesson2 = create(:lesson, :exercise, level: user_level.level)
    in_progress_lesson = create(:user_lesson, user: user_level.user, lesson: lesson1, completed_at: nil)
    user_level.update!(current_user_lesson: in_progress_lesson)

    error = assert_raises(LessonInProgressError) do
      UserLesson::Start.(user_level.user, lesson2)
    end

    assert_equal "Complete current lesson before starting a new one", error.message
  end

  test "allows starting new lesson when previous is completed" do
    user_level = create(:user_level)
    lesson1 = create(:lesson, :exercise, level: user_level.level)
    lesson2 = create(:lesson, :exercise, level: user_level.level)
    create(:user_lesson, user: user_level.user, lesson: lesson1, completed_at: Time.current)
    user_level.update!(current_user_lesson: nil)

    assert_nothing_raised do
      UserLesson::Start.(user_level.user, lesson2)
    end
  end

  test "raises LevelNotCompletedError when trying to start lesson in next level" do
    user_course = create(:user_course)
    level1 = create(:level, course: user_course.course, position: 1)
    level2 = create(:level, course: user_course.course, position: 2)
    lesson1 = create(:lesson, :exercise, level: level1)
    lesson2 = create(:lesson, :exercise, level: level2)
    user_level1 = create(:user_level, user: user_course.user, level: level1)
    user_course.update!(current_user_level: user_level1)
    create(:user_lesson, user: user_course.user, lesson: lesson1, completed_at: Time.current)
    create(:user_level, user: user_course.user, level: level2)

    error = assert_raises(LevelNotCompletedError) do
      UserLesson::Start.(user_course.user, lesson2)
    end

    assert_equal "Complete the current level before starting lessons in the next level", error.message
  end

  test "allows starting lesson in current level" do
    user_level = create(:user_level)
    lesson = create(:lesson, :exercise, level: user_level.level)
    user_course = UserCourse.find_by(user: user_level.user, course: user_level.course)
    user_course.update!(current_user_level: user_level)

    assert_nothing_raised do
      UserLesson::Start.(user_level.user, lesson)
    end
  end

  test "updates user_level.current_user_lesson on first creation" do
    user_level = create(:user_level)
    lesson = create(:lesson, :exercise, level: user_level.level)

    result = UserLesson::Start.(user_level.user, lesson)

    assert_equal result.id, user_level.reload.current_user_lesson_id
  end

  test "updates user_course.current_user_level on first creation" do
    user_level = create(:user_level)
    lesson = create(:lesson, :exercise, level: user_level.level)
    user_course = UserCourse.find_by(user: user_level.user, course: user_level.course)

    UserLesson::Start.(user_level.user, lesson)

    assert_equal user_level.id, user_course.reload.current_user_level_id
  end

  test "does not update tracking pointers on subsequent calls" do
    user_level = create(:user_level)
    lesson = create(:lesson, :exercise, level: user_level.level)
    user_course = UserCourse.find_by(user: user_level.user, course: user_level.course)
    first_user_lesson = UserLesson::Start.(user_level.user, lesson)

    assert_equal first_user_lesson.id, user_level.reload.current_user_lesson_id
    assert_equal user_level.id, user_course.reload.current_user_level_id

    second_user_lesson = UserLesson::Start.(user_level.user, lesson)
    assert_equal first_user_lesson.id, second_user_lesson.id
    assert_equal first_user_lesson.id, user_level.reload.current_user_lesson_id
    assert_equal user_level.id, user_course.reload.current_user_level_id
  end

  test "initializes with nil completed_at" do
    user_level = create(:user_level)
    lesson = create(:lesson, :exercise, level: user_level.level)

    result = UserLesson::Start.(user_level.user, lesson)

    assert_nil result.completed_at
  end

  test "sets created_at on creation" do
    user_level = create(:user_level)
    lesson = create(:lesson, :exercise, level: user_level.level)

    time_before = Time.current
    result = UserLesson::Start.(user_level.user, lesson)
    time_after = Time.current

    assert result.created_at >= time_before
    assert result.created_at <= time_after
  end
end
