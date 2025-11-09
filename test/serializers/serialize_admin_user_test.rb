require "test_helper"

class SerializeAdminUserTest < ActiveSupport::TestCase
  test "serializes user with all attributes" do
    user = create(:user, name: "Test User", email: "test@example.com", locale: "en", admin: false)

    expected = {
      id: user.id,
      name: "Test User",
      email: "test@example.com",
      locale: "en",
      admin: false
    }

    assert_equal expected, SerializeAdminUser.(user)
  end

  test "serializes admin user" do
    user = create(:user, :admin, name: "Admin User", email: "admin@example.com")

    result = SerializeAdminUser.(user)

    assert result[:admin]
    assert_equal "Admin User", result[:name]
  end

  test "serializes hungarian locale user" do
    user = create(:user, :hungarian, locale: "hu")

    result = SerializeAdminUser.(user)

    assert_equal "hu", result[:locale]
  end
end
