require "test_helper"

class UserLesson::CompleteBonusTest < ActiveSupport::TestCase
  test "sets bonus_completed_at" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    user_lesson = create(:user_lesson, user:, lesson:)

    UserLesson::CompleteBonus.(user, lesson)

    assert user_lesson.reload.bonus_completed_at.present?
  end

  test "sets bonus_completed_at to the current time" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    user_lesson = create(:user_lesson, user:, lesson:)

    travel_to Time.utc(2026, 9, 8, 12, 0, 0) do
      UserLesson::CompleteBonus.(user, lesson)
    end

    assert_equal Time.utc(2026, 9, 8, 12, 0, 0), user_lesson.reload.bonus_completed_at
  end

  test "is a high-water mark: never moves once set" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    original = Time.utc(2026, 9, 1, 12, 0, 0)
    user_lesson = create(:user_lesson, user:, lesson:, bonus_completed_at: original)

    travel_to Time.utc(2026, 9, 8, 12, 0, 0) do
      UserLesson::CompleteBonus.(user, lesson)
    end

    assert_equal original, user_lesson.reload.bonus_completed_at
  end

  test "works on a lesson that is not yet completed" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    user_lesson = create(:user_lesson, user:, lesson:, completed_at: nil)

    UserLesson::CompleteBonus.(user, lesson)

    user_lesson.reload
    assert user_lesson.bonus_completed_at.present?
    assert_nil user_lesson.completed_at
  end

  test "raises error if user_lesson doesn't exist" do
    user = create(:user)
    lesson = create(:lesson, :exercise)

    assert_raises(UserLessonNotFoundError) do
      UserLesson::CompleteBonus.(user, lesson)
    end
  end

  test "tracks a lesson_bonus_completed event" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, :exercise, level:)
    create(:user_lesson, user:, lesson:)

    Analytics::TrackEvent.expects(:defer).with(
      user,
      "lesson_bonus_completed",
      properties: {
        lesson_id: lesson.id,
        lesson_slug: lesson.slug,
        level_id: level.id,
        level_slug: level.slug
      }
    )

    UserLesson::CompleteBonus.(user, lesson)
  end

  test "does not track an event when already set" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    create(:user_lesson, user:, lesson:, bonus_completed_at: Time.current)

    Analytics::TrackEvent.expects(:defer).never

    UserLesson::CompleteBonus.(user, lesson)
  end
end
