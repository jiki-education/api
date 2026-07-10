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
end
