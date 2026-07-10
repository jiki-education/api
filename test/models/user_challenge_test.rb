require "test_helper"

class UserChallengeTest < ActiveSupport::TestCase
  test "valid factory" do
    assert build(:user_challenge).valid?
  end

  test "requires user" do
    user_challenge = build(:user_challenge, user: nil)
    refute user_challenge.valid?
  end

  test "requires challenge" do
    user_challenge = build(:user_challenge, challenge: nil)
    refute user_challenge.valid?
  end

  test "enforces uniqueness of user and challenge combination" do
    user = create(:user)
    challenge = create(:challenge)
    create(:user_challenge, user: user, challenge: challenge)

    duplicate = build(:user_challenge, user: user, challenge: challenge)
    refute duplicate.valid?
  end

  test "allows same challenge for different users" do
    challenge = create(:challenge)
    user1 = create(:user)
    user2 = create(:user)

    create(:user_challenge, user: user1, challenge: challenge)
    assert build(:user_challenge, user: user2, challenge: challenge).valid?
  end

  test "allows same user for different challenges" do
    user = create(:user)
    challenge1 = create(:challenge)
    challenge2 = create(:challenge)

    create(:user_challenge, user: user, challenge: challenge1)
    assert build(:user_challenge, user: user, challenge: challenge2).valid?
  end

  test "started? returns true when started_at is present" do
    user_challenge = build(:user_challenge, :started)
    assert user_challenge.started?
  end

  test "started? returns false when started_at is nil" do
    user_challenge = build(:user_challenge)
    refute user_challenge.started?
  end

  test "completed? returns true when completed_at is present" do
    user_challenge = build(:user_challenge, :completed)
    assert user_challenge.completed?
  end

  test "completed? returns false when completed_at is nil" do
    user_challenge = build(:user_challenge)
    refute user_challenge.completed?
  end
  # Transitional read-both behaviour: challenge rows are stored under the
  # legacy "Project"/"UserProject" polymorphic names today and the new
  # "Challenge"/"UserChallenge" names once polymorphic_name is removed.
  # Delete these tests when the transitional read-both code is removed
  # after the backfill migration.
  test "assistant_conversation finds conversation stored under the legacy Project context_type" do
    user_challenge = create(:user_challenge)
    conversation = create(:assistant_conversation, user: user_challenge.user, context: user_challenge.challenge)

    assert_equal "Project", conversation.context_type
    assert_equal conversation, user_challenge.assistant_conversation
  end

  test "assistant_conversation finds conversation stored under the new Challenge context_type" do
    user_challenge = create(:user_challenge)
    conversation = create(:assistant_conversation, user: user_challenge.user, context: user_challenge.challenge)
    conversation.update_column(:context_type, "Challenge")

    assert_equal conversation, user_challenge.assistant_conversation
  end

  test "exercise_submissions includes rows stored under both polymorphic names" do
    user_challenge = create(:user_challenge)
    legacy_submission = create(:exercise_submission, context: user_challenge)
    new_submission = create(:exercise_submission, context: user_challenge)
    new_submission.update_column(:context_type, "UserChallenge")

    assert_equal "UserProject", legacy_submission.context_type
    assert_equal [legacy_submission, new_submission].sort_by(&:id),
      user_challenge.exercise_submissions.order(:id).to_a
  end

  test "destroying a user_challenge destroys submissions stored under both polymorphic names" do
    user_challenge = create(:user_challenge)
    create(:exercise_submission, context: user_challenge)
    new_submission = create(:exercise_submission, context: user_challenge)
    new_submission.update_column(:context_type, "UserChallenge")

    assert_difference "ExerciseSubmission.count", -2 do
      Prosopite.pause do
        user_challenge.destroy!
      end
    end
  end
end
