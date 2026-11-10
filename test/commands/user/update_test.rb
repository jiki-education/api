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

  test "marks user as internal" do
    user = create(:user)

    User::Update.(user, { internal: true })

    assert user.reload.internal?
  end

  test "unmarks user as internal" do
    user = create(:user)
    user.data.update_column(:internal, true)

    User::Update.(user.reload, { internal: false })

    refute user.reload.internal?
  end

  test "identifies the user without an IP when internal changes" do
    user = create(:user)
    Current.user_ip = "9.9.9.9"
    User::Identify.expects(:defer).with(user, user_ip: nil)

    User::Update.(user, { internal: true })
  ensure
    Current.reset
  end

  test "does not identify the user when internal is unchanged" do
    user = create(:user)
    User::Identify.expects(:defer).never

    User::Update.(user, { internal: false })
    User::Update.(user, { email: "new@example.com" })
  end
end
