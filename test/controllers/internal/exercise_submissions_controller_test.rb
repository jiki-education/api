require "test_helper"

class Internal::ExerciseSubmissionsControllerTest < ApplicationControllerTest
  setup do
    setup_user
    @scores = { "v" => 1, "score" => 15, "metrics" => { "scenarios" => 10, "distance" => 5 } }
  end

  guard_incorrect_token! :internal_exercise_submission_path, args: ["test-uuid"], method: :patch

  test "PATCH update calls UpdateProgressionScores and returns 200" do
    submission = create(:exercise_submission, context: create(:user_lesson, user: @current_user))

    ExerciseSubmission::UpdateProgressionScores.expects(:call).with do |sub, progression_scores|
      sub == submission && progression_scores.to_unsafe_h == @scores
    end

    patch internal_exercise_submission_path(submission.uuid),
      params: { progression_scores: @scores },
      as: :json

    assert_response :ok
    assert_json_response({})
  end

  test "PATCH update persists progression_scores for a lesson submission" do
    submission = create(:exercise_submission, context: create(:user_lesson, user: @current_user))

    patch internal_exercise_submission_path(submission.uuid),
      params: { progression_scores: @scores },
      as: :json

    assert_response :ok
    assert_equal @scores, submission.reload.progression_scores
  end

  test "PATCH update persists progression_scores for a challenge submission" do
    submission = create(:exercise_submission, context: create(:user_challenge, user: @current_user))

    patch internal_exercise_submission_path(submission.uuid),
      params: { progression_scores: @scores },
      as: :json

    assert_response :ok
    assert_equal @scores, submission.reload.progression_scores
  end

  test "PATCH update with malformed progression_scores still returns 200" do
    submission = create(:exercise_submission, context: create(:user_lesson, user: @current_user))

    patch internal_exercise_submission_path(submission.uuid),
      params: { progression_scores: "1:5,10,0" },
      as: :json

    assert_response :ok
    assert_nil submission.reload.progression_scores
  end

  test "PATCH update with no progression_scores still returns 200" do
    submission = create(:exercise_submission, context: create(:user_lesson, user: @current_user))

    patch internal_exercise_submission_path(submission.uuid), params: {}, as: :json

    assert_response :ok
    assert_nil submission.reload.progression_scores
  end

  test "PATCH update returns 404 for an unknown uuid" do
    patch internal_exercise_submission_path("nonexistent"),
      params: { progression_scores: @scores },
      as: :json

    assert_json_error(:not_found, error_type: :exercise_submission_not_found)
  end

  test "PATCH update returns 404 for another user's submission" do
    submission = create(:exercise_submission, context: create(:user_lesson))

    patch internal_exercise_submission_path(submission.uuid),
      params: { progression_scores: @scores },
      as: :json

    assert_json_error(:not_found, error_type: :exercise_submission_not_found)
    assert_nil submission.reload.progression_scores
  end
end
