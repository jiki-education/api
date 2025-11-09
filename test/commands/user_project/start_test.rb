require "test_helper"

class UserProject::StartTest < ActiveSupport::TestCase
  test "sets started_at timestamp" do
    user_project = create(:user_project)
    assert_nil user_project.started_at

    result = UserProject::Start.(user_project)

    refute_nil result.started_at
    assert_equal user_project, result
  end

  test "does not change started_at if already set" do
    user_project = create(:user_project, started_at: 2.hours.ago)
    original_started_at = user_project.started_at

    result = UserProject::Start.(user_project)

    assert_equal original_started_at, result.started_at
  end

  test "returns the user_project" do
    user_project = create(:user_project)

    result = UserProject::Start.(user_project)

    assert_equal user_project, result
  end
end
