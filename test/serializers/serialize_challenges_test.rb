require "test_helper"

class SerializeChallengesTest < ActiveSupport::TestCase
  test "serializes challenges without user (status is nil)" do
    challenge1 = create :challenge, slug: "calculator"
    challenge2 = create :challenge, slug: "todo"

    result = SerializeChallenges.([challenge1, challenge2])

    assert_equal 2, result.length
    assert_equal({
      slug: "calculator",
      exercise_slug: "calculator",
      status: nil
    }, result[0])
    assert_equal({
      slug: "todo",
      exercise_slug: "todo",
      status: nil
    }, result[1])
  end

  test "locked when the unlocking lesson has not been completed" do
    lesson = create :lesson, :exercise
    challenge = create :challenge, slug: "calculator",
      unlocked_by_lesson: lesson
    user = create :user

    result = SerializeChallenges.([challenge], for_user: user)

    assert_equal :locked, result[0][:status]
  end

  test "unlocked when the challenge has no unlocking lesson" do
    challenge = create :challenge, unlocked_by_lesson: nil
    user = create :user

    result = SerializeChallenges.([challenge], for_user: user)

    assert_equal :unlocked, result[0][:status]
  end

  test "unlocked when the user has completed the unlocking lesson" do
    lesson = create :lesson, :exercise
    challenge = create :challenge, unlocked_by_lesson: lesson
    user = create :user
    create :user_lesson, user:, lesson:, completed_at: Time.current

    result = SerializeChallenges.([challenge], for_user: user)

    assert_equal :unlocked, result[0][:status]
  end

  test "started when a user_challenge row has started_at" do
    challenge = create :challenge
    user = create :user
    create :user_challenge, user:, challenge:, started_at: Time.current, completed_at: nil

    result = SerializeChallenges.([challenge], for_user: user)

    assert_equal :started, result[0][:status]
  end

  test "completed when a user_challenge row has completed_at" do
    challenge = create :challenge
    user = create :user
    create :user_challenge, user:, challenge:, started_at: 2.days.ago, completed_at: Time.current

    result = SerializeChallenges.([challenge], for_user: user)

    assert_equal :completed, result[0][:status]
  end

  test "serializes mixed challenge statuses efficiently" do
    locked_lesson = create :lesson, :exercise
    challenge_locked = create :challenge, slug: "locked",
      unlocked_by_lesson: locked_lesson
    challenge_unlocked = create :challenge, slug: "unlocked"
    challenge_started = create :challenge, slug: "started"
    challenge_completed = create :challenge, slug: "completed"
    user = create :user

    create :user_challenge, user:, challenge: challenge_started, started_at: 2.days.ago, completed_at: nil
    create :user_challenge, user:, challenge: challenge_completed, started_at: 3.days.ago, completed_at: 1.day.ago

    result = SerializeChallenges.(
      [challenge_locked, challenge_unlocked, challenge_started, challenge_completed],
      for_user: user
    )

    assert_equal 4, result.length
    assert_equal :locked, result[0][:status]
    assert_equal :unlocked, result[1][:status]
    assert_equal :started, result[2][:status]
    assert_equal :completed, result[3][:status]
  end
end
