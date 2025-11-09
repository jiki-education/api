require "test_helper"

class SerializeAdminUsersTest < ActiveSupport::TestCase
  test "serializes multiple users" do
    user_1 = create(:user, name: "User 1", email: "user1@example.com")
    user_2 = create(:user, name: "User 2", email: "user2@example.com")

    expected = [
      {
        id: user_1.id,
        name: "User 1",
        email: "user1@example.com",
        locale: user_1.locale,
        admin: user_1.admin
      },
      {
        id: user_2.id,
        name: "User 2",
        email: "user2@example.com",
        locale: user_2.locale,
        admin: user_2.admin
      }
    ]

    assert_equal expected, SerializeAdminUsers.([user_1, user_2])
  end

  test "serializes empty array" do
    assert_empty SerializeAdminUsers.([])
  end

  test "calls SerializeUser for each user" do
    user_1 = create(:user)
    user_2 = create(:user)

    SerializeAdminUser.expects(:call).with(user_1).returns({ id: user_1.id })
    SerializeAdminUser.expects(:call).with(user_2).returns({ id: user_2.id })

    SerializeAdminUsers.([user_1, user_2])
  end
end
