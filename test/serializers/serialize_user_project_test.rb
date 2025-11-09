require "test_helper"

class SerializeUserProjectTest < ActiveSupport::TestCase
  test "serializes user_project with completed status" do
    project = create(:project, slug: "calculator")
    user_project = create(:user_project, project: project, completed_at: Time.current)

    expected = {
      project_slug: "calculator",
      status: "completed",
      conversation: [],
      data: { last_submission: nil }
    }

    assert_equal(expected, SerializeUserProject.(user_project))
  end

  test "serializes user_project with started status" do
    project = create(:project, slug: "calculator")
    user_project = create(:user_project, project: project, completed_at: nil, started_at: Time.current)

    expected = {
      project_slug: "calculator",
      status: "started",
      conversation: [],
      data: { last_submission: nil }
    }

    assert_equal(expected, SerializeUserProject.(user_project))
  end

  test "includes last_submission with submission" do
    project = create(:project, slug: "calculator")
    user_project = create(:user_project, project:)
    submission = create(:exercise_submission, context: user_project)
    file = create(:exercise_submission_file, exercise_submission: submission, filename: "calculator.rb")
    file.content.attach(io: StringIO.new("class Calculator\nend"), filename: "calculator.rb")

    result = SerializeUserProject.(user_project)

    assert_equal "calculator", result[:project_slug]
    assert_equal "started", result[:status]
    assert_empty result[:conversation]
    assert result[:data].key?(:last_submission)
    assert_equal submission.uuid, result[:data][:last_submission][:uuid]
    assert_equal 1, result[:data][:last_submission][:files].length
    assert_equal "calculator.rb", result[:data][:last_submission][:files][0][:filename]
    assert_equal "class Calculator\nend", result[:data][:last_submission][:files][0][:content]
  end

  test "includes last_submission as nil without submission" do
    project = create(:project, slug: "calculator")
    user_project = create(:user_project, project:)

    result = SerializeUserProject.(user_project)

    assert_equal "calculator", result[:project_slug]
    assert_equal "started", result[:status]
    assert_empty result[:conversation]
    assert result[:data].key?(:last_submission)
    assert_nil result[:data][:last_submission]
  end

  test "includes most recent submission when multiple exist" do
    project = create(:project, slug: "calculator")
    user_project = create(:user_project, project:)

    # Create older submission
    old_submission = create(:exercise_submission, context: user_project, created_at: 2.days.ago)
    old_file = create(:exercise_submission_file, exercise_submission: old_submission, filename: "old.rb")
    old_file.content.attach(io: StringIO.new("old code"), filename: "old.rb")

    # Create newer submission
    new_submission = create(:exercise_submission, context: user_project, created_at: 1.day.ago)
    new_file = create(:exercise_submission_file, exercise_submission: new_submission, filename: "new.rb")
    new_file.content.attach(io: StringIO.new("new code"), filename: "new.rb")

    result = SerializeUserProject.(user_project)

    assert_empty result[:conversation]
    assert_equal new_submission.uuid, result[:data][:last_submission][:uuid]
    assert_equal "new.rb", result[:data][:last_submission][:files][0][:filename]
    assert_equal "new code", result[:data][:last_submission][:files][0][:content]
  end

  test "serializes multiple files in submission" do
    project = create(:project, slug: "calculator")
    user_project = create(:user_project, project:)
    submission = create(:exercise_submission, context: user_project)

    file1 = create(:exercise_submission_file, exercise_submission: submission, filename: "calculator.rb")
    file1.content.attach(io: StringIO.new("main code"), filename: "calculator.rb")

    file2 = create(:exercise_submission_file, exercise_submission: submission, filename: "spec.rb")
    file2.content.attach(io: StringIO.new("test code"), filename: "spec.rb")

    result = SerializeUserProject.(user_project)

    assert_empty result[:conversation]
    assert_equal 2, result[:data][:last_submission][:files].length
    assert_equal "calculator.rb", result[:data][:last_submission][:files][0][:filename]
    assert_equal "main code", result[:data][:last_submission][:files][0][:content]
    assert_equal "spec.rb", result[:data][:last_submission][:files][1][:filename]
    assert_equal "test code", result[:data][:last_submission][:files][1][:content]
  end

  test "includes conversation messages when conversation exists" do
    project = create(:project, slug: "calculator")
    user_project = create(:user_project, project:)

    messages = [
      { "role" => "user", "content" => "How do I start this project?", "timestamp" => "2025-10-31T08:15:30.000Z" },
      { "role" => "assistant", "content" => "Let me guide you...", "timestamp" => "2025-10-31T08:15:35.000Z" }
    ]

    create(:assistant_conversation,
      user: user_project.user,
      context: project,
      messages: messages)

    result = SerializeUserProject.(user_project)

    assert_equal "calculator", result[:project_slug]
    assert_equal "started", result[:status]
    assert_equal messages, result[:conversation]
  end

  test "includes conversation with both conversation and submission" do
    project = create(:project, slug: "calculator")
    user_project = create(:user_project, project:)
    submission = create(:exercise_submission, context: user_project)
    file = create(:exercise_submission_file, exercise_submission: submission, filename: "calculator.rb")
    file.content.attach(io: StringIO.new("class Calculator\nend"), filename: "calculator.rb")

    messages = [
      { "role" => "user", "content" => "Need help", "timestamp" => "2025-10-31T08:15:30.000Z" }
    ]

    create(:assistant_conversation,
      user: user_project.user,
      context: project,
      messages: messages)

    result = SerializeUserProject.(user_project)

    assert_equal "calculator", result[:project_slug]
    assert_equal messages, result[:conversation]
    assert_equal submission.uuid, result[:data][:last_submission][:uuid]
  end
end
