require "test_helper"

class UserProject::CreateTest < ActiveSupport::TestCase
  test "creates user_project for user and project" do
    user = create(:user)
    project = create(:project)

    user_project = UserProject::Create.(user, project)

    assert user_project.persisted?
    assert_equal user, user_project.user
    assert_equal project, user_project.project
  end

  test "is idempotent - returns existing record if already exists" do
    user = create(:user)
    project = create(:project)

    first_call = UserProject::Create.(user, project)
    second_call = UserProject::Create.(user, project)

    assert_equal first_call.id, second_call.id
    assert_equal 1, UserProject.count
  end

  test "newly created user_project has nil timestamps" do
    user = create(:user)
    project = create(:project)

    user_project = UserProject::Create.(user, project)

    assert_nil user_project.started_at
    assert_nil user_project.completed_at
  end

  test "emits project_unlocked event when project is newly created" do
    user = create(:user)
    project = create(:project, slug: "calculator", title: "Calculator")

    Current.reset
    UserProject::Create.(user, project)

    events = Current.events
    assert_equal 1, events.length

    event = events.first
    assert_equal "project_unlocked", event[:type]
    assert_equal "calculator", event[:data][:project][:slug]
    assert_equal "Calculator", event[:data][:project][:title]
  end

  test "does not emit event when user_project already exists (idempotent)" do
    user = create(:user)
    project = create(:project)

    # Create once
    UserProject::Create.(user, project)

    # Reset events and create again
    Current.reset
    UserProject::Create.(user, project)

    # Should not emit event on second call
    assert_nil Current.events
  end
end
