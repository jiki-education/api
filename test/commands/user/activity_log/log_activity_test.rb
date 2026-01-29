require "test_helper"

class User::ActivityLog::LogActivityTest < ActiveSupport::TestCase
  test "sets activity_days value to ACTIVITY_PRESENT for given date" do
    user = create(:user)
    date = Date.new(2024, 1, 15)

    User::ActivityLog::LogActivity.(user, date)

    assert_equal User::ActivityData::ACTIVITY_PRESENT, user.activity_data.reload.activity_days["2024-01-15"]
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

  test "calls UpdateAggregates when value changed" do
    user = create(:user)
    date = Date.new(2024, 1, 15)

    User::ActivityLog::UpdateAggregates.expects(:call).with(user).once

    User::ActivityLog::LogActivity.(user, date)
  end

  test "does not call UpdateAggregates when value unchanged" do
    user = create(:user)
    date = Date.new(2024, 1, 15)
    user.activity_data.update!(
      activity_days: { "2024-01-15" => User::ActivityData::ACTIVITY_PRESENT }
    )

    User::ActivityLog::UpdateAggregates.expects(:call).never

    User::ActivityLog::LogActivity.(user, date)
  end

  test "calls Backfill when activity not already logged" do
    user = create(:user)
    date = Date.new(2024, 1, 15)

    User::ActivityLog::Backfill.expects(:call).with(user).once

    User::ActivityLog::LogActivity.(user, date)
  end

  test "does not call Backfill when activity already logged" do
    user = create(:user)
    date = Date.new(2024, 1, 15)
    user.activity_data.update!(
      activity_days: { "2024-01-15" => User::ActivityData::ACTIVITY_PRESENT }
    )

    User::ActivityLog::Backfill.expects(:call).never

    User::ActivityLog::LogActivity.(user, date)
  end
end
