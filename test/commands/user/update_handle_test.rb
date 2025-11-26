require "test_helper"

class User::UpdateHandleTest < ActiveSupport::TestCase
  test "updates user handle successfully" do
    user = create(:user, handle: "old-handle")

    User::UpdateHandle.(user, "new-handle")

    assert_equal "new-handle", user.reload.handle
  end

  test "raises on duplicate handle" do
    create(:user, handle: "taken-handle")
    user = create(:user, handle: "my-handle")

    assert_raises ActiveRecord::RecordInvalid do
      User::UpdateHandle.(user, "taken-handle")
    end

    assert_equal "my-handle", user.reload.handle
  end

  test "raises on blank handle" do
    user = create(:user, handle: "my-handle")

    assert_raises ActiveRecord::RecordInvalid do
      User::UpdateHandle.(user, "")
    end

    assert_equal "my-handle", user.reload.handle
  end
end
