require "test_helper"

class User::Flag::MarkTest < ActiveSupport::TestCase
  test "creates a flag" do
    user = create(:user)

    flag = User::Flag::Mark.(user, "welcome_modal")

    assert flag.persisted?
    assert_equal user, flag.user
    assert_equal "welcome_modal", flag.key
  end

  test "is idempotent when called twice with the same key" do
    user = create(:user)

    first = User::Flag::Mark.(user, "welcome_modal")
    second = User::Flag::Mark.(user, "welcome_modal")

    assert_equal first.id, second.id
    assert_equal 1, User::Flag.where(user:).count
  end

  test "stringifies symbol keys" do
    user = create(:user)

    flag = User::Flag::Mark.(user, :welcome_modal)

    assert_equal "welcome_modal", flag.key
  end

  test "scopes flags per user" do
    user_one = create(:user)
    user_two = create(:user)

    User::Flag::Mark.(user_one, "welcome_modal")
    User::Flag::Mark.(user_two, "welcome_modal")

    assert_equal 1, user_one.flags.count
    assert_equal 1, user_two.flags.count
  end
end
