require "test_helper"

class User::UpdateLocaleTest < ActiveSupport::TestCase
  test "updates locale successfully" do
    user = create(:user, locale: "en")

    User::UpdateLocale.(user, "hu")

    assert_equal "hu", user.reload.locale
  end

  test "raises on invalid locale" do
    user = create(:user, locale: "en")

    assert_raises ActiveRecord::RecordInvalid do
      User::UpdateLocale.(user, "invalid")
    end

    assert_equal "en", user.reload.locale
  end
end
