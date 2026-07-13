require "test_helper"

class Internal::Challenges::ExerciseSubmissionsControllerTest < ApplicationControllerTest
  setup do
    setup_user
    make_premium(@current_user)
    @challenge = create(:challenge)
    # Pre-create UserChallenge so it doesn't emit events during tests
    create(:user_challenge, user: @current_user, challenge: @challenge)
  end

  guard_incorrect_token! :internal_challenge_exercise_submissions_path, args: ["test-slug"], method: :post

  test "POST create successfully creates submission" do
    files = [
      { filename: "main.rb", code: "puts 'hello'" },
      { filename: "helper.rb", code: "def help\nend" }
    ]

    Prosopite.pause do
      post internal_challenge_exercise_submissions_path(challenge_slug: @challenge.slug),
        params: { submission: { files: } },
        as: :json
    end

    assert_response :created
    assert_json_response({})
  end

  test "POST create starts the UserChallenge" do
    files = [{ filename: "solution.rb", code: "# code" }]

    UserChallenge::Start.expects(:call).with(
      @current_user,
      @challenge
    ).returns(create(:user_challenge))

    post internal_challenge_exercise_submissions_path(challenge_slug: @challenge.slug),
      params: { submission: { files: } },
      as: :json

    assert_response :created
  end

  test "POST create returns 403 when challenge is locked" do
    lesson = create(:lesson, :exercise)
    @challenge.update!(unlocked_by_lesson: lesson)
    files = [{ filename: "solution.rb", code: "# code" }]

    post internal_challenge_exercise_submissions_path(challenge_slug: @challenge.slug),
      params: { submission: { files: } },
      as: :json

    assert_json_error(:forbidden, error_type: :challenge_locked)
  end

  test "POST create calls ExerciseSubmission::Create" do
    user_challenge = UserChallenge.find_by!(user: @current_user, challenge: @challenge)
    files = [{ filename: "test.rb", code: "puts 'test'" }]

    UserChallenge::Start.stubs(:call).returns(user_challenge)

    ExerciseSubmission::Create.expects(:call).with do |up, file_params|
      up == user_challenge &&
        file_params.length == 1 &&
        file_params[0]["filename"] == "test.rb" &&
        file_params[0]["code"] == "puts 'test'"
    end.returns(create(:exercise_submission, :for_challenge))

    post internal_challenge_exercise_submissions_path(challenge_slug: @challenge.slug),
      params: { submission: { files: } },
      as: :json

    assert_response :created
  end

  test "POST create passes progression_scores through to ExerciseSubmission::Create" do
    user_challenge = UserChallenge.find_by!(user: @current_user, challenge: @challenge)
    files = [{ filename: "test.rb", code: "puts 'test'" }]
    scores = { "version" => 1, "runs" => 5 }

    UserChallenge::Start.stubs(:call).returns(user_challenge)

    ExerciseSubmission::Create.expects(:call).with do |_up, _file_params, progression_scores:|
      progression_scores.to_h == scores
    end.returns(create(:exercise_submission, :for_challenge))

    post internal_challenge_exercise_submissions_path(challenge_slug: @challenge.slug),
      params: { submission: { files:, progression_scores: scores } },
      as: :json

    assert_response :created
  end

  test "POST create with malformed progression_scores still succeeds" do
    files = [{ filename: "test.rb", code: "puts 'test'" }]

    Prosopite.pause do
      post internal_challenge_exercise_submissions_path(challenge_slug: @challenge.slug),
        params: { submission: { files:, progression_scores: "1:5,10,0" } },
        as: :json
    end

    assert_response :created
    assert_nil ExerciseSubmission.last.progression_scores
  end

  test "POST create handles invalid challenge slug" do
    files = [{ filename: "test.rb", code: "code" }]

    post internal_challenge_exercise_submissions_path(challenge_slug: "nonexistent"),
      params: { submission: { files: } },
      as: :json

    assert_json_error(:not_found, error_type: :challenge_not_found)
  end

  test "POST create with multiple files" do
    files = [
      { filename: "file1.rb", code: "code1" },
      { filename: "file2.rb", code: "code2" },
      { filename: "file3.rb", code: "code3" }
    ]

    Prosopite.pause do
      post internal_challenge_exercise_submissions_path(challenge_slug: @challenge.slug),
        params: { submission: { files: } },
        as: :json
    end

    assert_response :created
  end

  test "POST create returns 422 for duplicate filenames" do
    files = [
      { filename: "main.rb", code: "code1" },
      { filename: "main.rb", code: "code2" }
    ]

    post internal_challenge_exercise_submissions_path(challenge_slug: @challenge.slug),
      params: { submission: { files: } },
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

    post internal_challenge_exercise_submissions_path(challenge_slug: @challenge.slug),
      params: { submission: { files: } },
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

    post internal_challenge_exercise_submissions_path(challenge_slug: @challenge.slug),
      params: { submission: { files: } },
      as: :json

    assert_response :unprocessable_entity
    assert_json_response({
      error: {
        type: "file_too_large",
        message: /File 'large.rb' is too large/
      }
    })
  end

  test "POST create returns 403 for non-premium user" do
    make_non_premium(@current_user)
    files = [{ filename: "main.rb", code: "puts 'hello'" }]

    post internal_challenge_exercise_submissions_path(challenge_slug: @challenge.slug),
      params: { submission: { files: } },
      as: :json

    assert_json_error(:forbidden, error_type: :premium_required)
  end

  test "POST create returns 422 for empty files array" do
    post internal_challenge_exercise_submissions_path(challenge_slug: @challenge.slug),
      params: { submission: { files: [] } },
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
