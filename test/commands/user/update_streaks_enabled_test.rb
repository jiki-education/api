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
end
