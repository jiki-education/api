require "test_helper"

class User::ActivityDataTest < ActiveSupport::TestCase
  test "belongs to user" do
    user = create(:user)
    activity_data = user.activity_data

    assert_equal user, activity_data.user
  end

  test "effective_timezone returns timezone when set" do
    user = create(:user)
    user.activity_data.update!(timezone: "America/New_York")

    assert_equal "America/New_York", user.activity_data.effective_timezone
  end

  test "effective_timezone returns UTC when timezone is nil" do
    user = create(:user)
    user.activity_data.update!(timezone: nil)

    assert_equal "UTC", user.activity_data.effective_timezone
  end

  test "effective_timezone returns UTC when timezone is empty string" do
    user = create(:user)
    user.activity_data.update!(timezone: "")

    assert_equal "UTC", user.activity_data.effective_timezone
  end

  test "activity_for returns value for given date" do
    user = create(:user)
    user.activity_data.update!(activity_days: { "2024-01-15" => 2 })

    assert_equal 2, user.activity_data.activity_for(Date.new(2024, 1, 15))
  end

  test "activity_for returns nil for date not in activity_days" do
    user = create(:user)
    user.activity_data.update!(activity_days: {})

    assert_nil user.activity_data.activity_for(Date.new(2024, 1, 15))
  end

  test "active_on? returns true for ACTIVITY_PRESENT value" do
    user = create(:user)
    user.activity_data.update!(activity_days: { "2024-01-15" => User::ActivityData::ACTIVITY_PRESENT })

    assert user.activity_data.active_on?(Date.new(2024, 1, 15))
  end

  test "active_on? returns true for STREAK_FREEZE_USED value" do
    user = create(:user)
    user.activity_data.update!(activity_days: { "2024-01-15" => User::ActivityData::STREAK_FREEZE_USED })

    assert user.activity_data.active_on?(Date.new(2024, 1, 15))
  end

  test "active_on? returns false for NO_ACTIVITY value" do
    user = create(:user)
    user.activity_data.update!(activity_days: { "2024-01-15" => User::ActivityData::NO_ACTIVITY })

    refute user.activity_data.active_on?(Date.new(2024, 1, 15))
  end

  test "active_on? returns false for date not in activity_days" do
    user = create(:user)
    user.activity_data.update!(activity_days: {})

    refute user.activity_data.active_on?(Date.new(2024, 1, 15))
  end
end
