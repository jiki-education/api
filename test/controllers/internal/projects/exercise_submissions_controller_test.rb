require "test_helper"

class Internal::Projects::ExerciseSubmissionsControllerTest < ApplicationControllerTest
  setup do
    setup_user
    @project = create(:project)
    # Pre-create UserProject so it doesn't emit events during tests
    create(:user_project, user: @current_user, project: @project)
  end

  guard_incorrect_token! :internal_project_exercise_submissions_path, args: ["test-slug"], method: :post

  test "POST create successfully creates submission" do
    files = [
      { filename: "main.rb", code: "puts 'hello'" },
      { filename: "helper.rb", code: "def help\nend" }
    ]

    Prosopite.pause do
      post internal_project_exercise_submissions_path(project_slug: @project.slug),
        params: { submission: { files: } },
        headers: @headers,
        as: :json
    end

    assert_response :created
    assert_json_response({})
  end

  test "POST create finds or creates UserProject" do
    files = [{ filename: "solution.rb", code: "# code" }]

    UserProject::Create.expects(:call).with(
      @current_user,
      @project
    ).returns(create(:user_project))

    post internal_project_exercise_submissions_path(project_slug: @project.slug),
      params: { submission: { files: } },
      headers: @headers,
      as: :json

    assert_response :created
  end

  test "POST create calls ExerciseSubmission::Create" do
    user_project = UserProject.find_by!(user: @current_user, project: @project)
    files = [{ filename: "test.rb", code: "puts 'test'" }]

    UserProject::Create.stubs(:call).returns(user_project)

    ExerciseSubmission::Create.expects(:call).with do |up, file_params|
      up == user_project &&
        file_params.length == 1 &&
        file_params[0]["filename"] == "test.rb" &&
        file_params[0]["code"] == "puts 'test'"
    end.returns(create(:exercise_submission, :for_project))

    post internal_project_exercise_submissions_path(project_slug: @project.slug),
      params: { submission: { files: } },
      headers: @headers,
      as: :json

    assert_response :created
  end

  test "POST create handles invalid project slug" do
    files = [{ filename: "test.rb", code: "code" }]

    post internal_project_exercise_submissions_path(project_slug: "nonexistent"),
      params: { submission: { files: } },
      headers: @headers,
      as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Project not found"
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
      post internal_project_exercise_submissions_path(project_slug: @project.slug),
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

    post internal_project_exercise_submissions_path(project_slug: @project.slug),
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

    post internal_project_exercise_submissions_path(project_slug: @project.slug),
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

    post internal_project_exercise_submissions_path(project_slug: @project.slug),
      params: { submission: { files: } },
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity
    assert_json_response({
      error: {
        type: "file_too_large",
        message: /File 'large.rb' is too large/
      }
    })
  end

  test "POST create returns 422 for empty files array" do
    post internal_project_exercise_submissions_path(project_slug: @project.slug),
      params: { submission: { files: [] } },
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity
    assert_json_response({
      error: {
        type: "invalid_submission",
        message: /at least one file/i
      }
    })
  end
end
