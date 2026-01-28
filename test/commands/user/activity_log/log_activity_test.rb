require "test_helper"

class User::ActivityLog::LogActivityTest < ActiveSupport::TestCase
  test "sets activity_days value to ACTIVITY_PRESENT for given date" do
    user = create(:user)
    date = Date.new(2024, 1, 15)

    User::ActivityLog::LogActivity.(user, date)

    assert_equal User::ActivityData::ACTIVITY_PRESENT, user.activity_data.reload.activity_days["2024-01-15"]
  end

  test "updates last_active_date when date is newer" do
    user = create(:user)
    user.activity_data.update!(last_active_date: Date.new(2024, 1, 10))
    date = Date.new(2024, 1, 15)

    User::ActivityLog::LogActivity.(user, date)

    assert_equal date, user.activity_data.reload.last_active_date
  end

  test "does not update last_active_date when date is older" do
    user = create(:user)
    user.activity_data.update!(last_active_date: Date.new(2024, 1, 20))
    date = Date.new(2024, 1, 15)

    User::ActivityLog::LogActivity.(user, date)

    assert_equal Date.new(2024, 1, 20), user.activity_data.reload.last_active_date
  end

  test "sets last_active_date when previously nil" do
    user = create(:user)
    date = Date.new(2024, 1, 15)

    User::ActivityLog::LogActivity.(user, date)

    assert_equal date, user.activity_data.reload.last_active_date
  end

  test "is idempotent - calling twice produces same result" do
    user = create(:user)
    date = Date.new(2024, 1, 15)

    User::ActivityLog::LogActivity.(user, date)
    first_activity_days = user.activity_data.reload.activity_days.dup

    User::ActivityLog::LogActivity.(user, date)
    second_activity_days = user.activity_data.reload.activity_days

    assert_equal first_activity_days, second_activity_days
  end

  test "does not call UpdateAggregates when value unchanged" do
    user = create(:user)
    date = Date.new(2024, 1, 15)
    user.activity_data.update!(
      activity_days: { "2024-01-15" => User::ActivityData::ACTIVITY_PRESENT },
      current_streak: 5
    )

    # Since value is already set, UpdateAggregates should not be called
    # and current_streak should remain unchanged
    User::ActivityLog::LogActivity.(user, date)

    assert_equal 5, user.activity_data.reload.current_streak
  end

  test "creates activity_data if it does not exist" do
    user = create(:user)
    user.activity_data.destroy!
    user.reload

    assert_nil user.activity_data

    User::ActivityLog::LogActivity.(user, Date.current)

    refute_nil user.reload.activity_data
  end
end
