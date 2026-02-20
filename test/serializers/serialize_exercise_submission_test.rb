require "test_helper"

class SerializeExerciseSubmissionTest < ActiveSupport::TestCase
  test "returns correct structure for lesson submission" do
    user = create(:user)
    lesson = create(:lesson, :exercise, slug: "test-lesson")
    user_lesson = create(:user_lesson, user:, lesson:)
    submission = create(:exercise_submission, context: user_lesson, uuid: "abc123")

    create(:exercise_submission_file,
      exercise_submission: submission,
      filename: "main.rb")
    create(:exercise_submission_file,
      exercise_submission: submission,
      filename: "helper.rb")

    # Reload with includes to avoid N+1 (callers are expected to preload)
    submission = ExerciseSubmission.includes(files: { content_attachment: :blob }).find(submission.id)

    expected = {
      uuid: "abc123",
      context_type: "UserLesson",
      context_slug: "test-lesson",
      files: [
        { filename: "helper.rb", content: "puts 'hello'" },
        { filename: "main.rb", content: "puts 'hello'" }
      ]
    }

    assert_equal expected, SerializeExerciseSubmission.(submission)
  end

  test "returns correct structure for project submission" do
    user = create(:user)
    project = create(:project, slug: "test-project")
    user_project = create(:user_project, user:, project:)
    submission = create(:exercise_submission, context: user_project, uuid: "def456")

    create(:exercise_submission_file,
      exercise_submission: submission,
      filename: "solution.rb")

    expected = {
      uuid: "def456",
      context_type: "UserProject",
      context_slug: "test-project",
      files: [
        { filename: "solution.rb", content: "puts 'hello'" }
      ]
    }

    assert_equal expected, SerializeExerciseSubmission.(submission)
  end

  test "handles submission with no files" do
    user_lesson = create(:user_lesson)
    submission = create(:exercise_submission, context: user_lesson)

    result = SerializeExerciseSubmission.(submission)

    assert_empty result[:files]
  end
end
