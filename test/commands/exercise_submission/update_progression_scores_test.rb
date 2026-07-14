require "test_helper"

class ExerciseSubmission::UpdateProgressionScoresTest < ActiveSupport::TestCase
  test "persists progression_scores when a valid object is given" do
    submission = create(:exercise_submission)
    scores = { "version" => 1, "runs" => 5, "errors" => 0 }

    ExerciseSubmission::UpdateProgressionScores.(submission, scores)

    assert_equal scores, submission.reload.progression_scores
  end

  test "silently normalizes malformed progression_scores to nil" do
    Prosopite.pause do
      [
        "1:5,10,0",
        [1, 2, 3],
        { "runs" => "5" },
        { "runs" => 1.5 },
        { "runs" => nil },
        { "runs" => true },
        {},
        42,
        nil
      ].each do |bad|
        submission = create(:exercise_submission)

        ExerciseSubmission::UpdateProgressionScores.(submission, bad)

        assert_nil submission.reload.progression_scores, "expected #{bad.inspect} to normalize to nil"
      end
    end
  end

  test "accepts ActionController::Parameters" do
    submission = create(:exercise_submission)
    params = ActionController::Parameters.new(runs: 5, errors: 0).permit!

    ExerciseSubmission::UpdateProgressionScores.(submission, params)

    assert_equal({ "runs" => 5, "errors" => 0 }, submission.reload.progression_scores)
  end
end
