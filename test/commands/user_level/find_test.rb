require "test_helper"

class UserLevel::FindTest < ActiveSupport::TestCase
  test "finds existing user_level" do
    user = create(:user)
    level = create(:level)
    user_level = create(:user_level, user:, level:)

    result = UserLevel::Find.(user, level)

    assert_equal user_level.id, result.id
  end

  test "raises UserLevelNotFoundError when user_level doesn't exist" do
    user = create(:user)
    level = create(:level)

    error = assert_raises(UserLevelNotFoundError) do
      UserLevel::Find.(user, level)
    end

    assert_equal "Level not available", error.message
  end

  test "finds correct user_level for user" do
    user1 = create(:user)
    user2 = create(:user)
    level = create(:level)
    user_level1 = create(:user_level, user: user1, level:)
    create(:user_level, user: user2, level:)

    result = UserLevel::Find.(user1, level)

    assert_equal user_level1.id, result.id
  end

  test "finds correct user_level for level" do
    user = create(:user)
    level1 = create(:level)
    level2 = create(:level)
    user_level1 = create(:user_level, user:, level: level1)
    create(:user_level, user:, level: level2)

    result = UserLevel::Find.(user, level1)

    assert_equal user_level1.id, result.id
  end
end
