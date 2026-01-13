require "test_helper"

class User::UpdateNameTest < ActiveSupport::TestCase
  test "updates user name successfully" do
    user = create(:user, name: "Old Name")

    User::UpdateName.(user, "New Name")

    assert_equal "New Name", user.reload.name
  end

  test "allows blank name" do
    user = create(:user, name: "Old Name")

    User::UpdateName.(user, "")

    assert_equal "", user.reload.name
  end

  test "allows nil name" do
    user = create(:user, name: "Old Name")

    User::UpdateName.(user, nil)

    assert_nil user.reload.name
  end
end
