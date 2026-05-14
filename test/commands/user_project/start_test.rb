require "test_helper"

class UserProject::StartTest < ActiveSupport::TestCase
  test "creates user_project and sets started_at" do
    user = create(:user)
    project = create(:project)

    freeze_time do
      result = UserProject::Start.(user, project)

      assert result.persisted?
      assert_equal user, result.user
      assert_equal project, result.project
      assert_equal Time.current, result.started_at
    end
  end

  test "is idempotent - does not change started_at if already set" do
    user = create(:user)
    project = create(:project)
    user_project = create(:user_project, user:, project:, started_at: 2.hours.ago)
    original_started_at = user_project.started_at

    result = UserProject::Start.(user, project)

    assert_equal user_project, result
    assert_equal original_started_at, result.started_at
  end

  test "sets started_at on an existing unstarted user_project" do
    user = create(:user)
    project = create(:project)
    create(:user_project, user:, project:, started_at: nil)

    result = UserProject::Start.(user, project)

    refute_nil result.started_at
  end

  test "raises ProjectLockedError when project is locked for user" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    project = create(:project, unlocked_by_lesson: lesson)

    assert_raises(ProjectLockedError) do
      UserProject::Start.(user, project)
    end

    assert_equal 0, UserProject.count
  end

  test "starts project once the unlocking lesson is completed" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    project = create(:project, unlocked_by_lesson: lesson)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)

    result = UserProject::Start.(user, project)

    assert result.persisted?
    refute_nil result.started_at
  end
end
