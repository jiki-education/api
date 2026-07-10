require "test_helper"

class UserChallenge::StartTest < ActiveSupport::TestCase
  test "creates user_challenge and sets started_at" do
    user = create(:user)
    challenge = create(:challenge)

    freeze_time do
      result = UserChallenge::Start.(user, challenge)

      assert result.persisted?
      assert_equal user, result.user
      assert_equal challenge, result.challenge
      assert_equal Time.current, result.started_at
    end
  end

  test "is idempotent - does not change started_at if already set" do
    user = create(:user)
    challenge = create(:challenge)
    user_challenge = create(:user_challenge, user:, challenge:, started_at: 2.hours.ago)
    original_started_at = user_challenge.started_at

    result = UserChallenge::Start.(user, challenge)

    assert_equal user_challenge, result
    assert_equal original_started_at, result.started_at
  end

  test "sets started_at on an existing unstarted user_challenge" do
    user = create(:user)
    challenge = create(:challenge)
    create(:user_challenge, user:, challenge:, started_at: nil)

    result = UserChallenge::Start.(user, challenge)

    refute_nil result.started_at
  end

  test "raises ChallengeLockedError when challenge is locked for user" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    challenge = create(:challenge, unlocked_by_lesson: lesson)

    assert_raises(ChallengeLockedError) do
      UserChallenge::Start.(user, challenge)
    end

    assert_equal 0, UserChallenge.count
  end

  test "starts challenge once the unlocking lesson is completed" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    challenge = create(:challenge, unlocked_by_lesson: lesson)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)

    result = UserChallenge::Start.(user, challenge)

    assert result.persisted?
    refute_nil result.started_at
  end
end
