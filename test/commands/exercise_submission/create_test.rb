require "test_helper"

class ExerciseSubmission::CreateTest < ActiveSupport::TestCase
  test "creates submission with UUID for user_lesson" do
    user_lesson = create(:user_lesson)
    files = [{ filename: "main.rb", code: "puts 'hello'" }]

    submission = ExerciseSubmission::Create.(user_lesson, files)

    assert submission.persisted?
    assert submission.uuid.present?
    assert_equal user_lesson, submission.context
    assert_equal "UserLesson", submission.context_type
  end

  test "creates submission with UUID for user_project" do
    user_project = create(:user_project)
    files = [{ filename: "main.rb", code: "puts 'hello'" }]

    submission = ExerciseSubmission::Create.(user_project, files)

    assert submission.persisted?
    assert submission.uuid.present?
    assert_equal user_project, submission.context
    assert_equal "UserProject", submission.context_type
  end

  test "creates all files via File::Create" do
    user_lesson = create(:user_lesson)
    files = [
      { filename: "main.rb", code: "puts 'hello'" },
      { filename: "helper.rb", code: "def help\nend" }
    ]

    Prosopite.pause do
      submission = ExerciseSubmission::Create.(user_lesson, files)

      assert_equal 2, submission.files.count
      assert_equal ["helper.rb", "main.rb"], submission.files.map(&:filename).sort
    end
  end

  test "associates with user_lesson correctly" do
    user_lesson = create(:user_lesson)
    files = [{ filename: "solution.rb", code: "# solution" }]

    submission = ExerciseSubmission::Create.(user_lesson, files)

    assert_equal user_lesson.user, submission.user
    assert_equal user_lesson, submission.context
  end

  test "associates with user_project correctly" do
    user_project = create(:user_project)
    files = [{ filename: "solution.rb", code: "# solution" }]

    submission = ExerciseSubmission::Create.(user_project, files)

    assert_equal user_project.user, submission.user
    assert_equal user_project, submission.context
  end

  test "each file has correct digest" do
    user_lesson = create(:user_lesson)
    code = "puts 'test'"
    files = [{ filename: "test.rb", code: }]

    submission = ExerciseSubmission::Create.(user_lesson, files)

    file = submission.files.first
    assert_equal XXhash.xxh64(code).to_s, file.digest
  end

  test "raises DuplicateFilenameError for duplicate filenames" do
    user_lesson = create(:user_lesson)
    files = [
      { filename: "main.rb", code: "code1" },
      { filename: "main.rb", code: "code2" }
    ]

    error = assert_raises(DuplicateFilenameError) do
      ExerciseSubmission::Create.(user_lesson, files)
    end

    assert_match(/Duplicate filenames: main.rb/, error.message)
  end

  test "raises DuplicateFilenameError for multiple duplicate filenames" do
    user_lesson = create(:user_lesson)
    files = [
      { filename: "main.rb", code: "code1" },
      { filename: "main.rb", code: "code2" },
      { filename: "helper.rb", code: "code3" },
      { filename: "helper.rb", code: "code4" }
    ]

    error = assert_raises(DuplicateFilenameError) do
      ExerciseSubmission::Create.(user_lesson, files)
    end

    assert_match(/Duplicate filenames:/, error.message)
    assert_match(/main.rb/, error.message)
    assert_match(/helper.rb/, error.message)
  end

  test "raises TooManyFilesError for more than 20 files" do
    user_lesson = create(:user_lesson)
    files = Array.new(21) { |i| { filename: "file#{i}.rb", code: "code#{i}" } }

    error = assert_raises(TooManyFilesError) do
      ExerciseSubmission::Create.(user_lesson, files)
    end

    assert_equal "Too many files (maximum 20)", error.message
  end

  test "allows exactly 20 files" do
    user_lesson = create(:user_lesson)
    files = Array.new(20) { |i| { filename: "file#{i}.rb", code: "code#{i}" } }

    Prosopite.pause do
      submission = ExerciseSubmission::Create.(user_lesson, files)
      assert_equal 20, submission.files.count
    end
  end
end
