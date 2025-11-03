require "test_helper"

class User::DestroyTest < ActiveSupport::TestCase
  test "successfully destroys user" do
    user = create(:user)
    user_id = user.id

    assert_difference -> { User.count }, -1 do
      User::Destroy.(user)
    end

    assert_nil User.find_by(id: user_id)
  end

  test "destroys associated records due to dependent: :destroy" do
    user = create(:user)
    create(:user_lesson, user: user)
    create(:user_level, user: user)

    assert_difference -> { UserLesson.count }, -1 do
      assert_difference -> { UserLevel.count }, -1 do
        User::Destroy.(user)
      end
    end
  end

  test "handles circular foreign key constraint with current_user_level" do
    user = create(:user)
    user_level = create(:user_level, user: user)

    # Set the circular reference
    user.update_column(:current_user_level_id, user_level.id)

    # This should not raise a foreign key constraint error
    assert_nothing_raised do
      User::Destroy.(user)
    end

    # Verify user and associated records are deleted
    assert_nil User.find_by(id: user.id)
    assert_nil UserLevel.find_by(id: user_level.id)
  end
end
