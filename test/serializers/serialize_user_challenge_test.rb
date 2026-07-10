require "test_helper"

class SerializeUserChallengeTest < ActiveSupport::TestCase
  test "serializes user_challenge with completed status" do
    challenge = create(:challenge, slug: "calculator")
    user_challenge = create(:user_challenge, challenge: challenge, completed_at: Time.current)

    expected = {
      challenge_slug: "calculator",
      status: "completed",
      conversation: [],
      conversation_allowed: true,
      data: { last_submission: nil }
    }

    assert_equal(expected, SerializeUserChallenge.(user_challenge))
  end

  test "serializes user_challenge with started status" do
    challenge = create(:challenge, slug: "calculator")
    user_challenge = create(:user_challenge, challenge: challenge, completed_at: nil, started_at: Time.current)

    expected = {
      challenge_slug: "calculator",
      status: "started",
      conversation: [],
      conversation_allowed: true,
      data: { last_submission: nil }
    }

    assert_equal(expected, SerializeUserChallenge.(user_challenge))
  end

  test "includes last_submission with submission" do
    challenge = create(:challenge, slug: "calculator")
    user_challenge = create(:user_challenge, challenge:)
    submission = create(:exercise_submission, context: user_challenge)
    file = create(:exercise_submission_file, exercise_submission: submission, filename: "calculator.rb")
    file.content.attach(io: StringIO.new("class Calculator\nend"), filename: "calculator.rb")

    result = SerializeUserChallenge.(user_challenge)

    assert_equal "calculator", result[:challenge_slug]
    assert_equal "started", result[:status]
    assert_empty result[:conversation]
    assert result[:data].key?(:last_submission)
    assert_equal submission.uuid, result[:data][:last_submission][:uuid]
    assert_equal 1, result[:data][:last_submission][:files].length
    assert_equal "calculator.rb", result[:data][:last_submission][:files][0][:filename]
    assert_equal "class Calculator\nend", result[:data][:last_submission][:files][0][:content]
  end

  test "includes last_submission as nil without submission" do
    challenge = create(:challenge, slug: "calculator")
    user_challenge = create(:user_challenge, challenge:)

    result = SerializeUserChallenge.(user_challenge)

    assert_equal "calculator", result[:challenge_slug]
    assert_equal "started", result[:status]
    assert_empty result[:conversation]
    assert result[:data].key?(:last_submission)
    assert_nil result[:data][:last_submission]
  end

  test "returns nil last_submission when a file blob is missing from storage" do
    challenge = create(:challenge, slug: "calculator")
    user_challenge = create(:user_challenge, challenge:)
    submission = create(:exercise_submission, context: user_challenge)
    file = create(:exercise_submission_file, exercise_submission: submission, filename: "calculator.rb")
    file.content.attach(io: StringIO.new("class Calculator\nend"), filename: "calculator.rb")

    ActiveStorage::Blob.any_instance.stubs(:download).raises(ActiveStorage::FileNotFoundError)
    Sentry.expects(:capture_exception).with(instance_of(ActiveStorage::FileNotFoundError),
      extra: { exercise_submission_id: submission.id })

    result = SerializeUserChallenge.(user_challenge)

    assert_nil result[:data][:last_submission]
  end

  test "includes most recent submission when multiple exist" do
    challenge = create(:challenge, slug: "calculator")
    user_challenge = create(:user_challenge, challenge:)

    # Create older submission
    old_submission = create(:exercise_submission, context: user_challenge, created_at: 2.days.ago)
    old_file = create(:exercise_submission_file, exercise_submission: old_submission, filename: "old.rb")
    old_file.content.attach(io: StringIO.new("old code"), filename: "old.rb")

    # Create newer submission
    new_submission = create(:exercise_submission, context: user_challenge, created_at: 1.day.ago)
    new_file = create(:exercise_submission_file, exercise_submission: new_submission, filename: "new.rb")
    new_file.content.attach(io: StringIO.new("new code"), filename: "new.rb")

    result = SerializeUserChallenge.(user_challenge)

    assert_empty result[:conversation]
    assert_equal new_submission.uuid, result[:data][:last_submission][:uuid]
    assert_equal "new.rb", result[:data][:last_submission][:files][0][:filename]
    assert_equal "new code", result[:data][:last_submission][:files][0][:content]
  end

  test "serializes multiple files in submission" do
    challenge = create(:challenge, slug: "calculator")
    user_challenge = create(:user_challenge, challenge:)
    submission = create(:exercise_submission, context: user_challenge)

    file1 = create(:exercise_submission_file, exercise_submission: submission, filename: "calculator.rb")
    file1.content.attach(io: StringIO.new("main code"), filename: "calculator.rb")

    file2 = create(:exercise_submission_file, exercise_submission: submission, filename: "spec.rb")
    file2.content.attach(io: StringIO.new("test code"), filename: "spec.rb")

    result = SerializeUserChallenge.(user_challenge)

    assert_empty result[:conversation]
    assert_equal 2, result[:data][:last_submission][:files].length
    assert_equal "calculator.rb", result[:data][:last_submission][:files][0][:filename]
    assert_equal "main code", result[:data][:last_submission][:files][0][:content]
    assert_equal "spec.rb", result[:data][:last_submission][:files][1][:filename]
    assert_equal "test code", result[:data][:last_submission][:files][1][:content]
  end

  test "includes conversation messages when conversation exists" do
    challenge = create(:challenge, slug: "calculator")
    user_challenge = create(:user_challenge, challenge:)

    messages = [
      { "role" => "user", "content" => "How do I start this challenge?", "timestamp" => "2025-10-31T08:15:30.000Z" },
      { "role" => "assistant", "content" => "Let me guide you...", "timestamp" => "2025-10-31T08:15:35.000Z" }
    ]

    create(:assistant_conversation,
      user: user_challenge.user,
      context: challenge,
      messages: messages)

    result = SerializeUserChallenge.(user_challenge)

    assert_equal "calculator", result[:challenge_slug]
    assert_equal "started", result[:status]
    assert_equal messages, result[:conversation]
  end

  test "includes conversation with both conversation and submission" do
    challenge = create(:challenge, slug: "calculator")
    user_challenge = create(:user_challenge, challenge:)
    submission = create(:exercise_submission, context: user_challenge)
    file = create(:exercise_submission_file, exercise_submission: submission, filename: "calculator.rb")
    file.content.attach(io: StringIO.new("class Calculator\nend"), filename: "calculator.rb")

    messages = [
      { "role" => "user", "content" => "Need help", "timestamp" => "2025-10-31T08:15:30.000Z" }
    ]

    create(:assistant_conversation,
      user: user_challenge.user,
      context: challenge,
      messages: messages)

    result = SerializeUserChallenge.(user_challenge)

    assert_equal "calculator", result[:challenge_slug]
    assert_equal messages, result[:conversation]
    assert_equal submission.uuid, result[:data][:last_submission][:uuid]
  end
end
