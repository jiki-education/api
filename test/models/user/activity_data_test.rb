require "test_helper"

class User::ActivityDataTest < ActiveSupport::TestCase
  test "belongs to user" do
    user = create(:user)
    activity_data = user.activity_data

    assert_equal user, activity_data.user
  end
end
