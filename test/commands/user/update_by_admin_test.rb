require "test_helper"

class User::UpdateByAdminTest < ActiveSupport::TestCase
  test "updates email with valid params" do
    user = create(:user, email: "old@example.com")

    result = User::UpdateByAdmin.(
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
    result = User::UpdateByAdmin.(user, { email: "updated@example.com" })

    assert_equal user, result
    assert_equal "updated@example.com", result.email
  end

  test "raises validation error with blank email" do
    user = create(:user)

    error = assert_raises ActiveRecord::RecordInvalid do
      User::UpdateByAdmin.(user, { email: "" })
    end

    assert_match(/Email/, error.message)
  end

  test "raises validation error with invalid email format" do
    user = create(:user)

    error = assert_raises ActiveRecord::RecordInvalid do
      User::UpdateByAdmin.(user, { email: "not-an-email" })
    end

    assert_match(/Email/, error.message)
  end

  test "raises validation error for duplicate email" do
    create(:user, email: "existing@example.com")
    user = create(:user, email: "unique@example.com")

    assert_raises ActiveRecord::RecordInvalid do
      User::UpdateByAdmin.(user, { email: "existing@example.com" })
    end
  end

  test "updates admin flag when provided" do
    user = create(:user, admin: false)

    User::UpdateByAdmin.(user, { admin: true })

    assert user.reload.admin
  end

  test "raises validation error when demoting user 1" do
    user = create(:user, :admin, id: 1)

    error = assert_raises ActiveRecord::RecordInvalid do
      User::UpdateByAdmin.(user, { admin: false })
    end

    assert_match(/Admin/, error.message)
    assert user.reload.admin
  end

  test "raises validation error when demoting user 1 with a string param" do
    user = create(:user, :admin, id: 1)

    assert_raises ActiveRecord::RecordInvalid do
      User::UpdateByAdmin.(user, { admin: "false" })
    end

    assert user.reload.admin
  end

  test "allows updating user 1's email" do
    user = create(:user, :admin, id: 1, email: "old@example.com")

    User::UpdateByAdmin.(user, { email: "new@example.com" })

    assert_equal "new@example.com", user.reload.email
    assert user.admin
  end

  test "allows setting admin to true on user 1" do
    user = create(:user, :admin, id: 1)

    User::UpdateByAdmin.(user, { admin: true })

    assert user.reload.admin
  end

  test "allows demoting admins other than user 1" do
    user = create(:user, :admin)

    User::UpdateByAdmin.(user, { admin: false })

    refute user.reload.admin
  end

  test "ignores non-permitted fields in params" do
    user = create(:user, name: "Original Name", email: "original@example.com")

    User::UpdateByAdmin.(
      user,
      {
        email: "new@example.com",
        name: "Hacker Name",
        locale: "fr"
      }
    )

    user.reload
    assert_equal "new@example.com", user.email
    assert_equal "Original Name", user.name
    refute_equal "fr", user.locale
  end

  test "allows updating to same email (no-op)" do
    user = create(:user, email: "same@example.com")

    User::UpdateByAdmin.(user, { email: "same@example.com" })

    assert_equal "same@example.com", user.reload.email
  end
end
