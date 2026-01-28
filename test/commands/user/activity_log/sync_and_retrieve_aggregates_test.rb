require "test_helper"

class User::ActivityLog::SyncAndRetrieveAggregatesTest < ActiveSupport::TestCase
  test "returns current_streak and total_active_days" do
    user = create(:user)
    user.activity_data.update!(current_streak: 5, total_active_days: 10)

    result = User::ActivityLog::SyncAndRetrieveAggregates.(user)

    assert_equal 5, result[:current_streak]
    assert_equal 10, result[:total_active_days]
  end

  test "returns default values when activity_data is nil" do
    user = create(:user)
    user.activity_data.destroy!
    user.reload

    result = User::ActivityLog::SyncAndRetrieveAggregates.(user)

    assert_equal 0, result[:current_streak]
    assert_equal 0, result[:total_active_days]
  end

  test "returns hash with expected keys" do
    user = create(:user)

    result = User::ActivityLog::SyncAndRetrieveAggregates.(user)

    assert result.key?(:current_streak)
    assert result.key?(:total_active_days)
  end
end
