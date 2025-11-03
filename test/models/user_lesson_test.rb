require "test_helper"

class UserLessonTest < ActiveSupport::TestCase
  test "valid factory" do
    assert build(:user_lesson).valid?
  end

  test "unique user and lesson combination" do
    user = create(:user)
    lesson = create(:lesson)

    create(:user_lesson, user:, lesson:)
    duplicate = build(:user_lesson, user:, lesson:)

    refute duplicate.valid?
  end

  test "deleting user_lesson nullifies current_user_lesson reference in user_level" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)

    user_level = create(:user_level, user:, level:)
    user_lesson = create(:user_lesson, user:, lesson:)

    # Set user_lesson as current for user_level
    user_level.update!(current_user_lesson: user_lesson)

    assert_equal user_lesson.id, user_level.current_user_lesson_id

    # Delete the user_lesson
    user_lesson.destroy!

    # Reload user_level and verify current_user_lesson_id is nullified
    user_level.reload
    assert_nil user_level.current_user_lesson_id
  end

  test "deleting user_lesson cascades to delete exercise_submissions" do
    user = create(:user)
    lesson = create(:lesson)
    user_lesson = create(:user_lesson, user:, lesson:)

    # Create exercise submissions for this user_lesson
    submission1 = create(:exercise_submission, context: user_lesson)
    submission2 = create(:exercise_submission, context: user_lesson)

    submission1_id = submission1.id
    submission2_id = submission2.id

    # Delete the user_lesson (pause Prosopite since cascade deletes cause expected N+1 queries)
    Prosopite.pause do
      user_lesson.destroy!
    end

    # Verify exercise_submissions are deleted
    refute ExerciseSubmission.exists?(submission1_id)
    refute ExerciseSubmission.exists?(submission2_id)
  end
end
