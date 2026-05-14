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
end
