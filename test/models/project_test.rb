require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "valid factory" do
    assert build(:project).valid?
  end

  test "requires title" do
    project = build(:project, title: nil)
    refute project.valid?
  end

  test "requires description" do
    project = build(:project, description: nil)
    refute project.valid?
  end

  test "requires exercise_slug" do
    project = build(:project, exercise_slug: nil)
    refute project.valid?
  end

  test "requires unique slug" do
    create(:project, slug: "calculator")
    duplicate = build(:project, slug: "calculator")
    refute duplicate.valid?
  end

  test "auto-generates slug from title on create" do
    project = create(:project, title: "Todo App", slug: nil)
    assert_equal "todo-app", project.slug
  end

  test "preserves provided slug" do
    project = create(:project, title: "Todo App", slug: "custom-slug")
    assert_equal "custom-slug", project.slug
  end

  test "to_param returns slug" do
    project = create(:project, slug: "calculator")
    assert_equal "calculator", project.to_param
  end

  test "does not auto-regenerate slug when title changes" do
    project = create(:project, title: "Original Title", slug: "custom-slug")

    project.update!(title: "Completely Different Title")

    assert_equal "custom-slug", project.reload.slug
    refute_equal "completely-different-title", project.slug
  end

  test "can be unlocked by a lesson" do
    lesson = create(:lesson, :exercise)
    project = create(:project, unlocked_by_lesson: lesson)
    assert_equal lesson, project.unlocked_by_lesson
  end

  test "has many user_projects" do
    project = create(:project)
    user1 = create(:user)
    user2 = create(:user)

    create(:user_project, project: project, user: user1)
    create(:user_project, project: project, user: user2)

    assert_equal 2, project.user_projects.count
  end

  test "has many users through user_projects" do
    project = create(:project)
    user1 = create(:user)
    user2 = create(:user)

    create(:user_project, project: project, user: user1)
    create(:user_project, project: project, user: user2)

    assert_equal 2, project.users.count
    assert_includes project.users, user1
    assert_includes project.users, user2
  end
end
