require "test_helper"

class SerializeProjectsTest < ActiveSupport::TestCase
  test "serializes projects without user (status is nil)" do
    project1 = create :project, slug: "calculator", title: "Calculator", description: "Build a calculator"
    project2 = create :project, slug: "todo", title: "Todo App", description: "Build a todo app"

    result = SerializeProjects.([project1, project2])

    assert_equal 2, result.length
    assert_equal({
      slug: "calculator",
      title: "Calculator",
      description: "Build a calculator",
      status: nil
    }, result[0])
    assert_equal({
      slug: "todo",
      title: "Todo App",
      description: "Build a todo app",
      status: nil
    }, result[1])
  end

  test "locked when the unlocking lesson has not been completed" do
    lesson = create :lesson, :exercise
    project = create :project, slug: "calculator", title: "Calculator", description: "Build a calculator",
      unlocked_by_lesson: lesson
    user = create :user

    result = SerializeProjects.([project], for_user: user)

    assert_equal :locked, result[0][:status]
  end

  test "unlocked when the project has no unlocking lesson" do
    project = create :project, unlocked_by_lesson: nil
    user = create :user

    result = SerializeProjects.([project], for_user: user)

    assert_equal :unlocked, result[0][:status]
  end

  test "unlocked when the user has completed the unlocking lesson" do
    lesson = create :lesson, :exercise
    project = create :project, unlocked_by_lesson: lesson
    user = create :user
    create :user_lesson, user:, lesson:, completed_at: Time.current

    result = SerializeProjects.([project], for_user: user)

    assert_equal :unlocked, result[0][:status]
  end

  test "started when a user_project row has started_at" do
    project = create :project
    user = create :user
    create :user_project, user:, project:, started_at: Time.current, completed_at: nil

    result = SerializeProjects.([project], for_user: user)

    assert_equal :started, result[0][:status]
  end

  test "completed when a user_project row has completed_at" do
    project = create :project
    user = create :user
    create :user_project, user:, project:, started_at: 2.days.ago, completed_at: Time.current

    result = SerializeProjects.([project], for_user: user)

    assert_equal :completed, result[0][:status]
  end

  test "serializes mixed project statuses efficiently" do
    locked_lesson = create :lesson, :exercise
    project_locked = create :project, slug: "locked", title: "Locked", description: "Locked",
      unlocked_by_lesson: locked_lesson
    project_unlocked = create :project, slug: "unlocked", title: "Unlocked", description: "Unlocked"
    project_started = create :project, slug: "started", title: "Started", description: "Started"
    project_completed = create :project, slug: "completed", title: "Completed", description: "Completed"
    user = create :user

    create :user_project, user:, project: project_started, started_at: 2.days.ago, completed_at: nil
    create :user_project, user:, project: project_completed, started_at: 3.days.ago, completed_at: 1.day.ago

    result = SerializeProjects.(
      [project_locked, project_unlocked, project_started, project_completed],
      for_user: user
    )

    assert_equal 4, result.length
    assert_equal :locked, result[0][:status]
    assert_equal :unlocked, result[1][:status]
    assert_equal :started, result[2][:status]
    assert_equal :completed, result[3][:status]
  end
end
