require "test_helper"

class Internal::ExerciseSubmissionsControllerTest < ApplicationControllerTest
  setup do
    setup_user
    @lesson = create(:lesson, :exercise)
  end

  guard_incorrect_token! :internal_exercise_submission_path, args: ["test-uuid"], method: :patch

  # PATCH /internal/exercise_submissions/:uuid (progression scores) tests
  test "PATCH update calls UpdateProgressionScores and returns 200" do
    user_lesson = create(:user_lesson, user: @current_user, lesson: @lesson)
    submission = create(:exercise_submission, context: user_lesson)
    scores = { "version" => 1, "runs" => 5 }

    ExerciseSubmission::UpdateProgressionScores.expects(:call).with do |sub, progression_scores|
      sub == submission && progression_scores.to_h == scores
    end

    patch internal_exercise_submission_path(submission.uuid),
      params: { submission: { progression_scores: scores } },
      as: :json

    assert_response :ok
    assert_json_response({})
  end

  test "PATCH update persists progression_scores for a challenge submission" do
    user_challenge = create(:user_challenge, user: @current_user)
    submission = create(:exercise_submission, context: user_challenge)
    scores = { "version" => 1, "runs" => 5 }

    patch internal_exercise_submission_path(submission.uuid),
      params: { submission: { progression_scores: scores } },
      as: :json

    assert_response :ok
    assert_equal scores, submission.reload.progression_scores
  end

  test "PATCH update with malformed progression_scores still returns 200" do
    user_lesson = create(:user_lesson, user: @current_user, lesson: @lesson)
    submission = create(:exercise_submission, context: user_lesson)

    patch internal_exercise_submission_path(submission.uuid),
      params: { submission: { progression_scores: "1:5,10,0" } },
      as: :json

    assert_response :ok
    assert_nil submission.reload.progression_scores
  end

  test "PATCH update returns 404 for an unknown uuid" do
    patch internal_exercise_submission_path("nonexistent"),
      params: { submission: { progression_scores: { "runs" => 1 } } },
      as: :json

    assert_json_error(:not_found, error_type: :exercise_submission_not_found)
  end

  test "PATCH update returns 404 for another user's submission" do
    submission = create(:exercise_submission, context: create(:user_lesson))

    patch internal_exercise_submission_path(submission.uuid),
      params: { submission: { progression_scores: { "runs" => 1 } } },
      as: :json

    assert_json_error(:not_found, error_type: :exercise_submission_not_found)
  end
end
