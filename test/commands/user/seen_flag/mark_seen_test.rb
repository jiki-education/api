require "test_helper"

class User::SeenFlag::MarkSeenTest < ActiveSupport::TestCase
  test "creates a seen flag" do
    user = create(:user)

    flag = User::SeenFlag::MarkSeen.(user, "welcome_modal")

    assert flag.persisted?
    assert_equal user, flag.user
    assert_equal "welcome_modal", flag.key
  end

  test "is idempotent when called twice with the same key" do
    user = create(:user)

    first = User::SeenFlag::MarkSeen.(user, "welcome_modal")
    second = User::SeenFlag::MarkSeen.(user, "welcome_modal")

    assert_equal first.id, second.id
    assert_equal 1, User::SeenFlag.where(user:).count
  end

  test "stringifies symbol keys" do
    user = create(:user)

    flag = User::SeenFlag::MarkSeen.(user, :welcome_modal)

    assert_equal "welcome_modal", flag.key
  end

  test "scopes flags per user" do
    user_one = create(:user)
    user_two = create(:user)

    User::SeenFlag::MarkSeen.(user_one, "welcome_modal")
    User::SeenFlag::MarkSeen.(user_two, "welcome_modal")

    assert_equal 1, user_one.seen_flags.count
    assert_equal 1, user_two.seen_flags.count
  end
end
