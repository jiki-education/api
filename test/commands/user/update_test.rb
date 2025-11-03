require "test_helper"

class User::UpdateTest < ActiveSupport::TestCase
  test "updates email with valid params" do
    user = create(:user, email: "old@example.com")

    result = User::Update.(
      user,
      {
        email: "new@example.com"
      }
    )

    assert_equal user, result
    assert_equal "new@example.com", user.reload.email
  end

  test "returns updated user" do
    user = create(:user)
    result = User::Update.(user, { email: "updated@example.com" })

    assert_equal user, result
    assert_equal "updated@example.com", result.email
  end

  test "raises validation error with blank email" do
    user = create(:user)

    error = assert_raises ActiveRecord::RecordInvalid do
      User::Update.(user, { email: "" })
    end

    assert_match(/Email/, error.message)
  end

  test "raises validation error with invalid email format" do
    user = create(:user)

    error = assert_raises ActiveRecord::RecordInvalid do
      User::Update.(user, { email: "not-an-email" })
    end

    assert_match(/Email/, error.message)
  end

  test "raises validation error for duplicate email" do
    create(:user, email: "existing@example.com")
    user = create(:user, email: "unique@example.com")

    assert_raises ActiveRecord::RecordInvalid do
      User::Update.(user, { email: "existing@example.com" })
    end
  end

  test "ignores non-email fields in params" do
    user = create(:user, name: "Original Name", email: "original@example.com", admin: false)

    User::Update.(
      user,
      {
        email: "new@example.com",
        name: "Hacker Name",
        admin: true,
        locale: "fr"
      }
    )

    user.reload
    assert_equal "new@example.com", user.email
    assert_equal "Original Name", user.name
    refute user.admin
    refute_equal "fr", user.locale
  end

  test "allows updating to same email (no-op)" do
    user = create(:user, email: "same@example.com")

    User::Update.(user, { email: "same@example.com" })

    assert_equal "same@example.com", user.reload.email
  end
end
