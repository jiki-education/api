require "test_helper"

class UserLesson::SetRatingsTest < ActiveSupport::TestCase
  test "sets both ratings on user_lesson" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    user_lesson = create(:user_lesson, user:, lesson:)

    UserLesson::SetRatings.(user, lesson, 3, 5)

    user_lesson.reload
    assert_equal 3, user_lesson.difficulty_rating
    assert_equal 5, user_lesson.fun_rating
  end

  test "raises error if user_lesson doesn't exist" do
    user = create(:user)
    lesson = create(:lesson, :exercise)

    assert_raises(UserLessonNotFoundError) do
      UserLesson::SetRatings.(user, lesson, 3, 5)
    end
  end

  test "allows nil ratings" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    create(:user_lesson, user:, lesson:, difficulty_rating: 3, fun_rating: 5)

    UserLesson::SetRatings.(user, lesson, nil, nil)

    user_lesson = UserLesson.find_by(user:, lesson:)
    assert_nil user_lesson.difficulty_rating
    assert_nil user_lesson.fun_rating
  end

  test "updates existing ratings" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    create(:user_lesson, user:, lesson:, difficulty_rating: 1, fun_rating: 1)

    UserLesson::SetRatings.(user, lesson, 4, 5)

    user_lesson = UserLesson.find_by(user:, lesson:)
    assert_equal 4, user_lesson.difficulty_rating
    assert_equal 5, user_lesson.fun_rating
  end

  test "raises validation error for invalid difficulty_rating" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    create(:user_lesson, user:, lesson:)

    assert_raises(ActiveRecord::RecordInvalid) do
      UserLesson::SetRatings.(user, lesson, 6, 3)
    end
  end

  test "raises validation error for invalid fun_rating" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    create(:user_lesson, user:, lesson:)

    assert_raises(ActiveRecord::RecordInvalid) do
      UserLesson::SetRatings.(user, lesson, 3, 0)
    end
  end
end
