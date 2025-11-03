require "test_helper"

class UserLevelTest < ActiveSupport::TestCase
  test "valid factory" do
    assert build(:user_level).valid?
  end

  test "unique user and level combination" do
    user = create(:user)
    level = create(:level)

    create(:user_level, user:, level:)
    duplicate = build(:user_level, user:, level:)

    refute duplicate.valid?
  end

  test "deleting user_level nullifies current_user_level reference in user" do
    user = create(:user)
    level = create(:level)

    user_level = create(:user_level, user:, level:)

    # Set user_level as current for user
    user.update!(current_user_level: user_level)

    assert_equal user_level.id, user.current_user_level_id

    # Delete the user_level
    user_level.destroy!

    # Reload user and verify current_user_level_id is nullified
    user.reload
    assert_nil user.current_user_level_id
  end
end
