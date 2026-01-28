require "test_helper"

class SerializeProfileTest < ActiveSupport::TestCase
  test "returns streaks_enabled value" do
    user = create(:user)
    user.data.update!(streaks_enabled: true)
    user.activity_data.update!(activity_days: { Date.current.to_s => User::ActivityData::ACTIVITY_PRESENT })

    result = SerializeProfile.(user)

    assert result[:streaks_enabled]
  end

  test "returns current_streak when streaks_enabled is true" do
    user = create(:user)
    user.data.update!(streaks_enabled: true)
    user.activity_data.update!(
      current_streak: 5,
      activity_days: { Date.current.to_s => User::ActivityData::ACTIVITY_PRESENT }
    )

    result = SerializeProfile.(user)

    assert_equal 5, result[:current_streak]
    refute result.key?(:total_active_days)
  end

  test "returns total_active_days when streaks_enabled is false" do
    user = create(:user)
    user.data.update!(streaks_enabled: false)
    user.activity_data.update!(
      total_active_days: 10,
      activity_days: { Date.current.to_s => User::ActivityData::ACTIVITY_PRESENT }
    )

    result = SerializeProfile.(user)

    assert_equal 10, result[:total_active_days]
    refute result.key?(:current_streak)
  end
end
