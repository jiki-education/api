require "test_helper"

class User::ActivityLog::SyncAndRetrieveAggregatesTest < ActiveSupport::TestCase
  test "returns current_streak and total_active_days when last activity is today" do
    user = create(:user)
    today = Date.current
    user.activity_data.update!(
      current_streak: 5,
      total_active_days: 10,
      activity_days: { today.to_s => User::ActivityData::ACTIVITY_PRESENT }
    )

    result = User::ActivityLog::SyncAndRetrieveAggregates.(user)

    assert_equal 5, result[:current_streak]
    assert_equal 10, result[:total_active_days]
  end

  test "returns current_streak and total_active_days when last activity is yesterday" do
    user = create(:user)
    yesterday = Date.current - 1.day
    user.activity_data.update!(
      current_streak: 3,
      total_active_days: 7,
      activity_days: { yesterday.to_s => User::ActivityData::ACTIVITY_PRESENT }
    )

    result = User::ActivityLog::SyncAndRetrieveAggregates.(user)

    assert_equal 3, result[:current_streak]
    assert_equal 7, result[:total_active_days]
  end

  test "calls backfill when last activity is older than yesterday" do
    user = create(:user)
    three_days_ago = Date.current - 3.days
    user.activity_data.update!(
      activity_days: { three_days_ago.to_s => User::ActivityData::ACTIVITY_PRESENT }
    )

    User::ActivityLog::SyncAndRetrieveAggregates.(user)

    # Backfill should have filled in the missing days
    activity_days = user.activity_data.reload.activity_days
    assert_equal User::ActivityData::NO_ACTIVITY, activity_days[(Date.current - 2.days).to_s]
    assert_equal User::ActivityData::NO_ACTIVITY, activity_days[(Date.current - 1.day).to_s]
  end

  test "returns hash with expected keys" do
    user = create(:user)
    user.activity_data.update!(
      activity_days: { Date.current.to_s => User::ActivityData::ACTIVITY_PRESENT }
    )

    result = User::ActivityLog::SyncAndRetrieveAggregates.(user)

    assert result.key?(:current_streak)
    assert result.key?(:total_active_days)
  end
end
