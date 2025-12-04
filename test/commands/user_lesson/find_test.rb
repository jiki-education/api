require "test_helper"

class UserLesson::FindTest < ActiveSupport::TestCase
  test "finds existing user_lesson" do
    user = create(:user)
    lesson = create(:lesson)
    user_lesson = create(:user_lesson, user:, lesson:)

    result = UserLesson::Find.(user, lesson)

    assert_equal user_lesson.id, result.id
  end

  test "raises UserLessonNotFoundError when user_lesson doesn't exist" do
    user = create(:user)
    lesson = create(:lesson)

    error = assert_raises(UserLessonNotFoundError) do
      UserLesson::Find.(user, lesson)
    end

    assert_equal "Lesson not started", error.message
  end

  test "finds correct user_lesson for user" do
    user1 = create(:user)
    user2 = create(:user)
    lesson = create(:lesson)
    user_lesson1 = create(:user_lesson, user: user1, lesson:)
    create(:user_lesson, user: user2, lesson:)

    result = UserLesson::Find.(user1, lesson)

    assert_equal user_lesson1.id, result.id
  end

  test "finds correct user_lesson for lesson" do
    user = create(:user)
    lesson1 = create(:lesson)
    lesson2 = create(:lesson)
    user_lesson1 = create(:user_lesson, user:, lesson: lesson1)
    create(:user_lesson, user:, lesson: lesson2)

    result = UserLesson::Find.(user, lesson1)

    assert_equal user_lesson1.id, result.id
  end
end
