require "test_helper"

class User::UpdateLocalesTest < ActiveSupport::TestCase
  test "stores parsed locales from the Accept-Language header" do
    user = create(:user)
    User::ParseAcceptLanguage.expects(:call).with("hu, en;q=0.8").returns(%w[hu en])

    User::UpdateLocales.(user, "hu, en;q=0.8")

    assert_equal %w[hu en], user.data.reload.locales
  end

  test "does not store anything when no locales are parsed" do
    user = create(:user)
    User::ParseAcceptLanguage.expects(:call).with(nil).returns([])

    User::UpdateLocales.(user, nil)

    assert_empty user.data.reload.locales
  end

  test "does not overwrite existing locales" do
    user = create(:user)
    user.data.update_column(:locales, %w[hu])
    User::ParseAcceptLanguage.expects(:call).never

    User::UpdateLocales.(user, "en")

    assert_equal %w[hu], user.data.reload.locales
  end

  test "overwrites existing locales with force: true" do
    user = create(:user)
    user.data.update_column(:locales, %w[hu])
    User::ParseAcceptLanguage.expects(:call).with("en").returns(%w[en])

    User::UpdateLocales.(user, "en", force: true)

    assert_equal %w[en], user.data.reload.locales
  end
end
