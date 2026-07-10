require "test_helper"

class UserChallenge::CompleteTest < ActiveSupport::TestCase
  test "sets completed_at timestamp" do
    user_challenge = create(:user_challenge)
    assert_nil user_challenge.completed_at

    result = UserChallenge::Complete.(user_challenge)

    refute_nil result.completed_at
    assert_equal user_challenge, result
  end

  test "does not change completed_at if already set" do
    user_challenge = create(:user_challenge, completed_at: 1.hour.ago)
    original_completed_at = user_challenge.completed_at

    result = UserChallenge::Complete.(user_challenge)

    assert_equal original_completed_at, result.completed_at
  end

  test "returns the user_challenge" do
    user_challenge = create(:user_challenge)

    result = UserChallenge::Complete.(user_challenge)

    assert_equal user_challenge, result
  end
end
