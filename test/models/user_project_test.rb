require "test_helper"

class UserProjectTest < ActiveSupport::TestCase
  test "valid factory" do
    assert build(:user_project).valid?
  end

  test "requires user" do
    user_project = build(:user_project, user: nil)
    refute user_project.valid?
  end

  test "requires project" do
    user_project = build(:user_project, project: nil)
    refute user_project.valid?
  end

  test "enforces uniqueness of user and project combination" do
    user = create(:user)
    project = create(:project)
    create(:user_project, user: user, project: project)

    duplicate = build(:user_project, user: user, project: project)
    refute duplicate.valid?
  end

  test "allows same project for different users" do
    project = create(:project)
    user1 = create(:user)
    user2 = create(:user)

    create(:user_project, user: user1, project: project)
    assert build(:user_project, user: user2, project: project).valid?
  end

  test "allows same user for different projects" do
    user = create(:user)
    project1 = create(:project)
    project2 = create(:project)

    create(:user_project, user: user, project: project1)
    assert build(:user_project, user: user, project: project2).valid?
  end

  test "started? returns true when started_at is present" do
    user_project = build(:user_project, :started)
    assert user_project.started?
  end

  test "started? returns false when started_at is nil" do
    user_project = build(:user_project)
    refute user_project.started?
  end

  test "completed? returns true when completed_at is present" do
    user_project = build(:user_project, :completed)
    assert user_project.completed?
  end

  test "completed? returns false when completed_at is nil" do
    user_project = build(:user_project)
    refute user_project.completed?
  end
end
