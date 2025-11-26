require "test_helper"

class Internal::ExerciseSubmissionsControllerTest < ApplicationControllerTest
  setup do
    setup_user
    @lesson = create(:lesson)
  end

  guard_incorrect_token! :internal_lesson_exercise_submissions_path, args: ["test-slug"], method: :post

  test "POST create successfully creates submission" do
    files = [
      { filename: "main.rb", code: "puts 'hello'" },
      { filename: "helper.rb", code: "def help\nend" }
    ]

    Prosopite.pause do
      post internal_lesson_exercise_submissions_path(lesson_slug: @lesson.slug),
        params: { submission: { files: } },
        headers: @headers,
        as: :json
    end

    assert_response :created
    assert_json_response({})
  end

  test "POST create finds or creates UserLesson" do
    files = [{ filename: "solution.rb", code: "# code" }]

    UserLesson::FindOrCreate.expects(:call).with(
      @current_user,
      @lesson
    ).returns(create(:user_lesson))

    post internal_lesson_exercise_submissions_path(lesson_slug: @lesson.slug),
      params: { submission: { files: } },
      headers: @headers,
      as: :json

    assert_response :created
  end

  test "POST create calls ExerciseSubmission::Create" do
    user_lesson = create(:user_lesson, user: @current_user, lesson: @lesson)
    files = [{ filename: "test.rb", code: "puts 'test'" }]

    UserLesson::FindOrCreate.stubs(:call).returns(user_lesson)

    ExerciseSubmission::Create.expects(:call).with do |ul, file_params|
      ul == user_lesson &&
        file_params.length == 1 &&
        file_params[0]["filename"] == "test.rb" &&
        file_params[0]["code"] == "puts 'test'"
    end.returns(create(:exercise_submission))

    post internal_lesson_exercise_submissions_path(lesson_slug: @lesson.slug),
      params: { submission: { files: } },
      headers: @headers,
      as: :json

    assert_response :created
  end

  test "POST create handles invalid lesson slug" do
    files = [{ filename: "test.rb", code: "code" }]

    post internal_lesson_exercise_submissions_path(lesson_slug: "nonexistent"),
      params: { submission: { files: } },
      headers: @headers,
      as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Lesson not found"
      }
    })
  end

  test "POST create with multiple files" do
    files = [
      { filename: "file1.rb", code: "code1" },
      { filename: "file2.rb", code: "code2" },
      { filename: "file3.rb", code: "code3" }
    ]

    Prosopite.pause do
      post internal_lesson_exercise_submissions_path(lesson_slug: @lesson.slug),
        params: { submission: { files: } },
        headers: @headers,
        as: :json
    end

    assert_response :created
  end

  test "POST create returns 422 for duplicate filenames" do
    files = [
      { filename: "main.rb", code: "code1" },
      { filename: "main.rb", code: "code2" }
    ]

    post internal_lesson_exercise_submissions_path(lesson_slug: @lesson.slug),
      params: { submission: { files: } },
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity
    assert_json_response({
      error: {
        type: "duplicate_filename",
        message: "Duplicate filenames: main.rb"
      }
    })
  end

  test "POST create returns 422 for too many files" do
    files = Array.new(21) { |i| { filename: "file#{i}.rb", code: "code#{i}" } }

    post internal_lesson_exercise_submissions_path(lesson_slug: @lesson.slug),
      params: { submission: { files: } },
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity
    assert_json_response({
      error: {
        type: "too_many_files",
        message: "Too many files (maximum 20)"
      }
    })
  end

  test "POST create returns 422 for file too large" do
    files = [
      { filename: "large.rb", code: "a" * 100_001 }
    ]

    post internal_lesson_exercise_submissions_path(lesson_slug: @lesson.slug),
      params: { submission: { files: } },
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity

    json_response = response.parsed_body
    assert_equal "file_too_large", json_response["error"]["type"]
    assert_match(/File 'large.rb' is too large/, json_response["error"]["message"])
  end

  test "POST create returns 422 for empty files array" do
    post internal_lesson_exercise_submissions_path(lesson_slug: @lesson.slug),
      params: { submission: { files: [] } },
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity

    json_response = response.parsed_body
    assert_equal "invalid_submission", json_response["error"]["type"]
    assert_match(/at least one file/i, json_response["error"]["message"])
  end

  test "POST create returns 422 for missing filename" do
    files = [{ code: "puts 'hello'" }]

    post internal_lesson_exercise_submissions_path(lesson_slug: @lesson.slug),
      params: { submission: { files: } },
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity

    json_response = response.parsed_body
    assert_equal "invalid_submission", json_response["error"]["type"]
    assert_match(/filename.*required/i, json_response["error"]["message"])
  end

  test "POST create returns 422 for null filename" do
    files = [{ filename: nil, code: "puts 'hello'" }]

    post internal_lesson_exercise_submissions_path(lesson_slug: @lesson.slug),
      params: { submission: { files: } },
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity

    json_response = response.parsed_body
    assert_equal "invalid_submission", json_response["error"]["type"]
    assert_match(/filename.*required/i, json_response["error"]["message"])
  end

  test "POST create returns 422 for missing code" do
    files = [{ filename: "main.rb" }]

    post internal_lesson_exercise_submissions_path(lesson_slug: @lesson.slug),
      params: { submission: { files: } },
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity

    json_response = response.parsed_body
    assert_equal "invalid_submission", json_response["error"]["type"]
    assert_match(/code.*required/i, json_response["error"]["message"])
  end

  test "POST create returns 422 for null code" do
    files = [{ filename: "main.rb", code: nil }]

    post internal_lesson_exercise_submissions_path(lesson_slug: @lesson.slug),
      params: { submission: { files: } },
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity

    json_response = response.parsed_body
    assert_equal "invalid_submission", json_response["error"]["type"]
    assert_match(/code.*required/i, json_response["error"]["message"])
  end
end
