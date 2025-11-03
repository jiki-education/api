require "test_helper"

class UserProject::CompleteTest < ActiveSupport::TestCase
  test "sets completed_at timestamp" do
    user_project = create(:user_project)
    assert_nil user_project.completed_at

    result = UserProject::Complete.(user_project)

    refute_nil result.completed_at
    assert_equal user_project, result
  end

  test "does not change completed_at if already set" do
    user_project = create(:user_project, completed_at: 1.hour.ago)
    original_completed_at = user_project.completed_at

    result = UserProject::Complete.(user_project)

    assert_equal original_completed_at, result.completed_at
  end

  test "returns the user_project" do
    user_project = create(:user_project)

    result = UserProject::Complete.(user_project)

    assert_equal user_project, result
  end
end
