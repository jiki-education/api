require "test_helper"

class ExerciseSubmission::UpdateProgressionScoresTest < ActiveSupport::TestCase
  test "persists progression_scores when a valid object is given" do
    submission = create(:exercise_submission)
    scores = { "v" => 1, "score" => 27, "metrics" => { "scenarios" => 10, "distance" => 5, "used_loop" => 10, "precision" => 2 } }

    ExerciseSubmission::UpdateProgressionScores.(submission, scores)

    assert_equal scores, submission.reload.progression_scores
  end

  test "persists zeroed scores for an exercise without custom metrics" do
    submission = create(:exercise_submission)
    scores = { "v" => 0, "score" => 0, "metrics" => { "scenarios" => 0 } }

    ExerciseSubmission::UpdateProgressionScores.(submission, scores)

    assert_equal scores, submission.reload.progression_scores
  end

  test "accepts symbol keys" do
    submission = create(:exercise_submission)

    ExerciseSubmission::UpdateProgressionScores.(submission, { v: 1, score: 10, metrics: { scenarios: 10 } })

    assert_equal({ "v" => 1, "score" => 10, "metrics" => { "scenarios" => 10 } }, submission.reload.progression_scores)
  end

  test "accepts ActionController::Parameters" do
    submission = create(:exercise_submission)
    params = ActionController::Parameters.new(v: 1, score: 15, metrics: { scenarios: 10, distance: 5 })

    ExerciseSubmission::UpdateProgressionScores.(submission, params)

    assert_equal(
      { "v" => 1, "score" => 15, "metrics" => { "scenarios" => 10, "distance" => 5 } },
      submission.reload.progression_scores
    )
  end

  test "drops unknown top-level keys" do
    submission = create(:exercise_submission)

    ExerciseSubmission::UpdateProgressionScores.(
      submission,
      { "v" => 1, "score" => 10, "metrics" => { "scenarios" => 10 }, "extra" => "ignored" }
    )

    assert_equal({ "v" => 1, "score" => 10, "metrics" => { "scenarios" => 10 } }, submission.reload.progression_scores)
  end

  test "silently normalizes malformed progression_scores to nil" do
    valid = { "v" => 1, "score" => 10, "metrics" => { "scenarios" => 10 } }

    Prosopite.pause do
      [
        "1:5,10,0",
        [1, 2, 3],
        42,
        nil,
        {},
        { "version" => 1, "runs" => 5 },
        valid.except("v"),
        valid.except("score"),
        valid.except("metrics"),
        valid.merge("v" => "1"),
        valid.merge("score" => 1.5),
        valid.merge("metrics" => [10]),
        valid.merge("metrics" => { "scenarios" => "10" }),
        valid.merge("metrics" => { "scenarios" => nil }),
        valid.merge("metrics" => { "scenarios" => true }),
        valid.merge("metrics" => { "scenarios" => { "nested" => 1 } })
      ].each do |bad|
        submission = create(:exercise_submission)

        ExerciseSubmission::UpdateProgressionScores.(submission, bad)

        assert_nil submission.reload.progression_scores, "expected #{bad.inspect} to normalize to nil"
      end
    end
  end
end
