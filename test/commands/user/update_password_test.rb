require "test_helper"

class User::UpdatePasswordTest < ActiveSupport::TestCase
  test "updates password successfully" do
    user = create(:user, password: "oldpassword123")
    old_encrypted = user.encrypted_password

    User::UpdatePassword.(user, "newpassword456")

    user.reload
    refute_equal old_encrypted, user.encrypted_password
    assert user.valid_password?("newpassword456")
  end

  test "raises on password too short" do
    user = create(:user, password: "oldpassword123")

    assert_raises ActiveRecord::RecordInvalid do
      User::UpdatePassword.(user, "short")
    end

    assert user.reload.valid_password?("oldpassword123")
  end
end
