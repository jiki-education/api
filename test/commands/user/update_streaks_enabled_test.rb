require "test_helper"

class User::UpdateStreaksEnabledTest < ActiveSupport::TestCase
  test "enables streaks" do
    user = create(:user)
    refute user.data.streaks_enabled

    User::UpdateStreaksEnabled.(user, true)

    assert user.data.reload.streaks_enabled
  end

  test "disables streaks" do
    user = create(:user)
    user.data.update!(streaks_enabled: true)

    User::UpdateStreaksEnabled.(user, false)

    refute user.data.reload.streaks_enabled
  end

  test "casts string values" do
    user = create(:user)

    User::UpdateStreaksEnabled.(user, "true")
    assert user.data.reload.streaks_enabled

    User::UpdateStreaksEnabled.(user, "false")
    refute user.data.reload.streaks_enabled
  end

  test "raises InvalidBooleanError for nil" do
    user = create(:user)

    assert_raises(InvalidBooleanError) do
      User::UpdateStreaksEnabled.(user, nil)
    end

    refute user.data.reload.streaks_enabled
  end

  test "raises InvalidBooleanError for empty string" do
    user = create(:user)

    assert_raises(InvalidBooleanError) do
      User::UpdateStreaksEnabled.(user, "")
    end
  end
end
