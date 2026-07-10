require "test_helper"

class UserChallenge::UnlockedForUserTest < ActiveSupport::TestCase
  test "true when challenge has no unlocking lesson" do
    user = create(:user)
    challenge = create(:challenge, unlocked_by_lesson: nil)

    assert UserChallenge::UnlockedForUser.(user, challenge)
  end

  test "false when challenge has an unlocking lesson the user has not completed" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    challenge = create(:challenge, unlocked_by_lesson: lesson)

    refute UserChallenge::UnlockedForUser.(user, challenge)
  end

  test "false when the unlocking lesson is started but not completed" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    challenge = create(:challenge, unlocked_by_lesson: lesson)
    create(:user_lesson, user:, lesson:, completed_at: nil)

    refute UserChallenge::UnlockedForUser.(user, challenge)
  end

  test "true when the user has completed the unlocking lesson" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    challenge = create(:challenge, unlocked_by_lesson: lesson)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)

    assert UserChallenge::UnlockedForUser.(user, challenge)
  end

  test "false when a different user completed the unlocking lesson" do
    user = create(:user)
    other_user = create(:user)
    lesson = create(:lesson, :exercise)
    challenge = create(:challenge, unlocked_by_lesson: lesson)
    create(:user_lesson, user: other_user, lesson:, completed_at: Time.current)

    refute UserChallenge::UnlockedForUser.(user, challenge)
  end
end
