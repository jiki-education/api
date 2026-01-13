require "test_helper"

class User::UpdateEmailTest < ActiveSupport::TestCase
  test "stores new email in unconfirmed_email with reconfirmable" do
    user = create(:user, email: "old@example.com", confirmed_at: Time.current)

    User::UpdateEmail.(user, "new@example.com")

    user.reload
    # With reconfirmable, new email goes to unconfirmed_email
    assert_equal "old@example.com", user.email
    assert_equal "new@example.com", user.unconfirmed_email
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
