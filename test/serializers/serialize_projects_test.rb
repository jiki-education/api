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

  test "serializes projects with user showing locked status" do
    project1 = create :project, slug: "calculator", title: "Calculator", description: "Build a calculator"
    project2 = create :project, slug: "todo", title: "Todo App", description: "Build a todo app"
    user = create :user

    result = SerializeProjects.([project1, project2], for_user: user)

    assert_equal 2, result.length
    assert_equal :locked, result[0][:status]
    assert_equal :locked, result[1][:status]
  end

  test "serializes projects with user showing unlocked status" do
    project = create :project, slug: "calculator", title: "Calculator", description: "Build a calculator"
    user = create :user
    create :user_project, user:, project:, started_at: nil, completed_at: nil

    result = SerializeProjects.([project], for_user: user)

    assert_equal 1, result.length
    assert_equal :unlocked, result[0][:status]
  end

  test "serializes projects with user showing started status" do
    project = create :project, slug: "calculator", title: "Calculator", description: "Build a calculator"
    user = create :user
    create :user_project, user:, project:, started_at: Time.current, completed_at: nil

    result = SerializeProjects.([project], for_user: user)

    assert_equal 1, result.length
    assert_equal :started, result[0][:status]
  end

  test "serializes projects with user showing completed status" do
    project = create :project, slug: "calculator", title: "Calculator", description: "Build a calculator"
    user = create :user
    create :user_project, user:, project:, started_at: 2.days.ago, completed_at: Time.current

    result = SerializeProjects.([project], for_user: user)

    assert_equal 1, result.length
    assert_equal :completed, result[0][:status]
  end

  test "serializes mixed project statuses efficiently" do
    project1 = create :project, slug: "calc", title: "Calculator", description: "Calc"
    project2 = create :project, slug: "todo", title: "Todo", description: "Todo"
    project3 = create :project, slug: "chat", title: "Chat", description: "Chat"
    project4 = create :project, slug: "blog", title: "Blog", description: "Blog"
    user = create :user

    # Different statuses
    create :user_project, user:, project: project2, started_at: nil, completed_at: nil # unlocked
    create :user_project, user:, project: project3, started_at: 2.days.ago, completed_at: nil # started
    create :user_project, user:, project: project4, started_at: 3.days.ago, completed_at: 1.day.ago # completed
    # project1 has no user_project, so it's locked

    result = SerializeProjects.([project1, project2, project3, project4], for_user: user)

    assert_equal 4, result.length
    assert_equal :locked, result[0][:status]
    assert_equal :unlocked, result[1][:status]
    assert_equal :started, result[2][:status]
    assert_equal :completed, result[3][:status]
  end
end
