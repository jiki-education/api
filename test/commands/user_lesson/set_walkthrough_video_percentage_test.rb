require "test_helper"

class UserLesson::SetWalkthroughVideoPercentageTest < ActiveSupport::TestCase
  test "sets percentage on user_lesson" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    user_lesson = create(:user_lesson, user:, lesson:)

    UserLesson::SetWalkthroughVideoPercentage.(user, lesson, 50)

    assert_equal 50, user_lesson.reload.walkthrough_video_watched_percentage
  end

  test "does not go backwards" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    user_lesson = create(:user_lesson, user:, lesson:, walkthrough_video_watched_percentage: 75)

    UserLesson::SetWalkthroughVideoPercentage.(user, lesson, 50)

    assert_equal 75, user_lesson.reload.walkthrough_video_watched_percentage
  end

  test "updates when percentage is higher" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    user_lesson = create(:user_lesson, user:, lesson:, walkthrough_video_watched_percentage: 50)

    UserLesson::SetWalkthroughVideoPercentage.(user, lesson, 75)

    assert_equal 75, user_lesson.reload.walkthrough_video_watched_percentage
  end

  test "updates from nil" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    user_lesson = create(:user_lesson, user:, lesson:)

    UserLesson::SetWalkthroughVideoPercentage.(user, lesson, 30)

    assert_equal 30, user_lesson.reload.walkthrough_video_watched_percentage
  end

  test "raises error if user_lesson doesn't exist" do
    user = create(:user)
    lesson = create(:lesson, :exercise)

    assert_raises(UserLessonNotFoundError) do
      UserLesson::SetWalkthroughVideoPercentage.(user, lesson, 50)
    end
  end

  test "clamps percentage over 100 to 100" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    user_lesson = create(:user_lesson, user:, lesson:)

    UserLesson::SetWalkthroughVideoPercentage.(user, lesson, 150)

    assert_equal 100, user_lesson.reload.walkthrough_video_watched_percentage
  end

  test "clamps negative percentage to 0" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    user_lesson = create(:user_lesson, user:, lesson:)

    UserLesson::SetWalkthroughVideoPercentage.(user, lesson, -10)

    assert_equal 0, user_lesson.reload.walkthrough_video_watched_percentage
  end
end
