require "test_helper"

class ExerciseSubmissionTest < ActiveSupport::TestCase
  test "validates presence of uuid" do
    submission = build(:exercise_submission, uuid: nil)

    refute submission.valid?
    assert_includes submission.errors[:uuid], "can't be blank"
  end

  test "validates uniqueness of uuid" do
    create(:exercise_submission, uuid: "test-uuid")
    duplicate = build(:exercise_submission, uuid: "test-uuid")

    refute duplicate.valid?
    assert_includes duplicate.errors[:uuid], "has already been taken"
  end

  test "validates presence of context" do
    submission = build(:exercise_submission, context: nil)

    refute submission.valid?
    assert_includes submission.errors[:context], "must exist"
  end

  test "delegates user to context for user_lesson" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    user_lesson = create(:user_lesson, user:, lesson:)
    submission = create(:exercise_submission, context: user_lesson)

    assert_equal user, submission.user
  end

  test "delegates user to context for user_project" do
    user = create(:user)
    project = create(:project)
    user_project = create(:user_project, user:, project:)
    submission = create(:exercise_submission, context: user_project)

    assert_equal user, submission.user
  end

  test "to_param returns uuid" do
    submission = create(:exercise_submission, uuid: "abc123")

    assert_equal "abc123", submission.to_param
  end

  test "destroys associated files when destroyed" do
    submission = create(:exercise_submission)
    create(:exercise_submission_file, exercise_submission: submission)

    assert_difference -> { ExerciseSubmission::File.count }, -1 do
      submission.destroy
    end
  end
end
