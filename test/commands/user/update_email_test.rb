require "test_helper"

class User::UpdateEmailTest < ActiveSupport::TestCase
  test "updates user email successfully" do
    user = create(:user, email: "old@example.com", email_verified: true)

    User::UpdateEmail.(user, "new@example.com")

    assert_equal "new@example.com", user.reload.email
  end

  test "sets email_verified to false" do
    user = create(:user, email: "old@example.com", email_verified: true)

    User::UpdateEmail.(user, "new@example.com")

    refute user.reload.email_verified
  end

  test "raises on invalid email format" do
    user = create(:user, email: "old@example.com")

    assert_raises ActiveRecord::RecordInvalid do
      User::UpdateEmail.(user, "invalid-email")
    end

    assert_equal "old@example.com", user.reload.email
  end

  test "raises on duplicate email" do
    create(:user, email: "taken@example.com")
    user = create(:user, email: "old@example.com")

    assert_raises ActiveRecord::RecordInvalid do
      User::UpdateEmail.(user, "taken@example.com")
    end

    assert_equal "old@example.com", user.reload.email
  end
end
