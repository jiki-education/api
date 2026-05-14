require "test_helper"

class UserProject::UnlockedForUserTest < ActiveSupport::TestCase
  test "true when project has no unlocking lesson" do
    user = create(:user)
    project = create(:project, unlocked_by_lesson: nil)

    assert UserProject::UnlockedForUser.(user, project)
  end

  test "false when project has an unlocking lesson the user has not completed" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    project = create(:project, unlocked_by_lesson: lesson)

    refute UserProject::UnlockedForUser.(user, project)
  end

  test "false when the unlocking lesson is started but not completed" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    project = create(:project, unlocked_by_lesson: lesson)
    create(:user_lesson, user:, lesson:, completed_at: nil)

    refute UserProject::UnlockedForUser.(user, project)
  end

  test "true when the user has completed the unlocking lesson" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    project = create(:project, unlocked_by_lesson: lesson)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)

    assert UserProject::UnlockedForUser.(user, project)
  end

  test "false when a different user completed the unlocking lesson" do
    user = create(:user)
    other_user = create(:user)
    lesson = create(:lesson, :exercise)
    project = create(:project, unlocked_by_lesson: lesson)
    create(:user_lesson, user: other_user, lesson:, completed_at: Time.current)

    refute UserProject::UnlockedForUser.(user, project)
  end
end
