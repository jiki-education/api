require "test_helper"

class Migrations::BackfillLocBonusesTest < ActiveSupport::TestCase
  # two-fer's limit is 6 in both languages.
  def setup_lesson(slug: "two-fer", language: "javascript")
    course = create(:course)
    level = create(:level, course:)
    lesson = create(:lesson, :exercise, level:, slug:)
    user = create(:user)
    create(:user_course, user:, course:, language:)
    [user, lesson]
  end

  def submit!(user_lesson, code, created_at: Time.current)
    submission = create(:exercise_submission, context: user_lesson, created_at:)
    ExerciseSubmission::File::Create.(submission, "main.js", code)
    submission
  end

  test "sets bonus_completed_at when the latest submission is within the limit" do
    user, lesson = setup_lesson
    user_lesson = create(:user_lesson, user:, lesson:, completed_at: Time.current)
    submission = submit!(user_lesson, "function twoFer(n) {\n  return n;\n}\n")

    Migrations::BackfillLocBonuses.()

    assert_equal submission.created_at, user_lesson.reload.bonus_completed_at
  end

  test "does not set it when the latest submission is over the limit" do
    user, lesson = setup_lesson
    user_lesson = create(:user_lesson, user:, lesson:, completed_at: Time.current)
    submit!(user_lesson, (1..7).map { |i| "let a#{i} = #{i};" }.join("\n"))

    Migrations::BackfillLocBonuses.()

    assert_nil user_lesson.reload.bonus_completed_at
  end

  test "scores only the most recent submission" do
    user, lesson = setup_lesson
    user_lesson = create(:user_lesson, user:, lesson:, completed_at: Time.current)
    submit!(user_lesson, "let a = 1;\nlet b = 2;\nlet c = 3;\n")
    submit!(user_lesson, (1..7).map { |i| "let a#{i} = #{i};" }.join("\n"))

    Migrations::BackfillLocBonuses.()

    assert_nil user_lesson.reload.bonus_completed_at
  end

  test "ignores submissions below the minimum line count" do
    user, lesson = setup_lesson
    user_lesson = create(:user_lesson, user:, lesson:, completed_at: Time.current)
    submit!(user_lesson, "let a = 1;\nlet b = 2;\n")

    Migrations::BackfillLocBonuses.()

    assert_nil user_lesson.reload.bonus_completed_at
  end

  test "ignores lessons that are not completed" do
    user, lesson = setup_lesson
    user_lesson = create(:user_lesson, user:, lesson:, completed_at: nil)
    submit!(user_lesson, "let a = 1;\nlet b = 2;\nlet c = 3;\n")

    Migrations::BackfillLocBonuses.()

    assert_nil user_lesson.reload.bonus_completed_at
  end

  test "ignores lessons without a LOC-based bonus" do
    user, lesson = setup_lesson(slug: "rna-transcription")
    user_lesson = create(:user_lesson, user:, lesson:, completed_at: Time.current)
    submit!(user_lesson, "let a = 1;\nlet b = 2;\nlet c = 3;\n")

    Migrations::BackfillLocBonuses.()

    assert_nil user_lesson.reload.bonus_completed_at
  end

  test "leaves an existing bonus_completed_at alone" do
    user, lesson = setup_lesson
    original = Time.utc(2026, 1, 1, 12, 0, 0)
    user_lesson = create(:user_lesson, user:, lesson:, completed_at: Time.current, bonus_completed_at: original)
    submit!(user_lesson, "let a = 1;\nlet b = 2;\nlet c = 3;\n")

    Migrations::BackfillLocBonuses.()

    assert_equal original, user_lesson.reload.bonus_completed_at
  end

  test "skips and counts submissions whose files are unreadable" do
    user, lesson = setup_lesson
    user_lesson = create(:user_lesson, user:, lesson:, completed_at: Time.current)
    submission = submit!(user_lesson, "let a = 1;\nlet b = 2;\nlet c = 3;\n")
    submission.files.each { |file| file.content.blob.service.delete(file.content.blob.key) }

    result = Migrations::BackfillLocBonuses.()

    assert_nil user_lesson.reload.bonus_completed_at
    assert_equal 1, result[:missing_files]
    assert_equal 0, result[:awarded]
  end

  test "returns a count of what it awarded" do
    user, lesson = setup_lesson
    user_lesson = create(:user_lesson, user:, lesson:, completed_at: Time.current)
    submit!(user_lesson, "function twoFer(n) {\n  return n;\n}\n")

    assert_equal({ awarded: 1, missing_files: 0 }, Migrations::BackfillLocBonuses.())
  end

  test "ignores lessons with no submissions" do
    user, lesson = setup_lesson
    user_lesson = create(:user_lesson, user:, lesson:, completed_at: Time.current)

    Migrations::BackfillLocBonuses.()

    assert_nil user_lesson.reload.bonus_completed_at
  end

  test "skips users who chose python" do
    code = "function twoFer(n) {\n  return n;\n}\n"

    python_user, lesson = setup_lesson(language: "python")
    course = lesson.level.course
    js_user = create(:user)
    create(:user_course, user: js_user, course:, language: "javascript")

    python_lesson = create(:user_lesson, user: python_user, lesson:, completed_at: Time.current)
    js_lesson = create(:user_lesson, user: js_user, lesson:, completed_at: Time.current)
    submit!(python_lesson, code)
    submit!(js_lesson, code)

    Migrations::BackfillLocBonuses.()

    assert_nil python_lesson.reload.bonus_completed_at
    assert js_lesson.reload.bonus_completed_at.present?
  end

  test "treats an unset language as javascript" do
    # sign-price's javascript limit is 9, so 8 lines qualifies.
    user, lesson = setup_lesson(slug: "sign-price", language: nil)
    user_lesson = create(:user_lesson, user:, lesson:, completed_at: Time.current)
    submit!(user_lesson, (1..8).map { |i| "let a#{i} = #{i};" }.join("\n"))

    Migrations::BackfillLocBonuses.()

    assert user_lesson.reload.bonus_completed_at.present?
  end

  test "counts lines across every file in the submission" do
    user, lesson = setup_lesson
    user_lesson = create(:user_lesson, user:, lesson:, completed_at: Time.current)
    submission = create(:exercise_submission, context: user_lesson)
    # two-fer's limit is 6: four lines per file is within it individually,
    # but eight together must not pass.
    ExerciseSubmission::File::Create.(submission, "a.js", (1..4).map { |i| "let a#{i} = #{i};" }.join("\n"))
    ExerciseSubmission::File::Create.(submission, "b.js", (1..4).map { |i| "let b#{i} = #{i};" }.join("\n"))

    Migrations::BackfillLocBonuses.()

    assert_nil user_lesson.reload.bonus_completed_at
  end
end
