require "test_helper"

class User::ActivityLog::UpdateAggregatesTest < ActiveSupport::TestCase
  test "values are correct with no activity" do
    user = create(:user)
    user.activity_data.update!(activity_days: {})

    User::ActivityLog::UpdateAggregates.(user)

    activity_data = user.activity_data.reload
    assert_equal 0, activity_data.current_streak
    assert_equal 0, activity_data.longest_streak
    assert_equal 0, activity_data.total_active_days
  end

  test "calculates current_streak from consecutive days ending today" do
    user = create(:user)
    today = Date.current
    user.activity_data.update!(activity_days: {
      (today - 2.days).to_s => User::ActivityData::ACTIVITY_PRESENT,
      (today - 1.day).to_s => User::ActivityData::ACTIVITY_PRESENT,
      today.to_s => User::ActivityData::ACTIVITY_PRESENT
    })

    User::ActivityLog::UpdateAggregates.(user)

    assert_equal 3, user.activity_data.reload.current_streak
  end

  test "calculates current_streak from consecutive days ending yesterday" do
    user = create(:user)
    today = Date.current
    user.activity_data.update!(activity_days: {
      (today - 3.days).to_s => User::ActivityData::ACTIVITY_PRESENT,
      (today - 2.days).to_s => User::ActivityData::ACTIVITY_PRESENT,
      (today - 1.day).to_s => User::ActivityData::ACTIVITY_PRESENT
    })

    User::ActivityLog::UpdateAggregates.(user)

    assert_equal 3, user.activity_data.reload.current_streak
  end

  test "streak breaks with no activity days" do
    user = create(:user)
    today = Date.current
    user.activity_data.update!(activity_days: {
      (today - 5.days).to_s => User::ActivityData::ACTIVITY_PRESENT,
      (today - 4.days).to_s => User::ActivityData::ACTIVITY_PRESENT,
      (today - 3.days).to_s => User::ActivityData::NO_ACTIVITY,
      (today - 2.days).to_s => User::ActivityData::NO_ACTIVITY,
      (today - 1.day).to_s => User::ActivityData::ACTIVITY_PRESENT,
      today.to_s => User::ActivityData::ACTIVITY_PRESENT
    })

    User::ActivityLog::UpdateAggregates.(user)

    assert_equal 2, user.activity_data.reload.current_streak
  end

  test "streak breaks with no recent activity" do
    user = create(:user)
    today = Date.current
    user.activity_data.update!(activity_days: {
      (today - 5.days).to_s => User::ActivityData::ACTIVITY_PRESENT,
      (today - 4.days).to_s => User::ActivityData::ACTIVITY_PRESENT
    })

    User::ActivityLog::UpdateAggregates.(user)

    assert_equal 0, user.activity_data.reload.current_streak
  end

  test "streak passes with activity today" do
    user = create(:user)
    today = Date.current
    user.activity_data.update!(activity_days: {
      (today - 3.days).to_s => User::ActivityData::ACTIVITY_PRESENT,
      (today - 2.days).to_s => User::ActivityData::ACTIVITY_PRESENT,
      (today - 1.day).to_s => User::ActivityData::ACTIVITY_PRESENT
    })

    User::ActivityLog::UpdateAggregates.(user)

    assert_equal 3, user.activity_data.reload.current_streak
  end

  test "streak continues with STREAK_FREEZE_USED value" do
    user = create(:user)
    today = Date.current
    user.activity_data.update!(activity_days: {
      (today - 2.days).to_s => User::ActivityData::ACTIVITY_PRESENT,
      (today - 1.day).to_s => User::ActivityData::STREAK_FREEZE_USED,
      today.to_s => User::ActivityData::ACTIVITY_PRESENT
    })

    User::ActivityLog::UpdateAggregates.(user)

    assert_equal 3, user.activity_data.reload.current_streak
  end

  test "longest_streak never decreases" do
    user = create(:user)
    user.activity_data.update!(
      activity_days: { Date.current.to_s => User::ActivityData::ACTIVITY_PRESENT },
      longest_streak: 10
    )

    User::ActivityLog::UpdateAggregates.(user)

    assert_equal 10, user.activity_data.reload.longest_streak
  end

  test "calculates total_active_days counting only ACTIVITY_PRESENT" do
    user = create(:user)
    today = Date.current
    user.activity_data.update!(activity_days: {
      (today - 2.days).to_s => User::ActivityData::ACTIVITY_PRESENT,
      (today - 1.day).to_s => User::ActivityData::STREAK_FREEZE_USED,
      today.to_s => User::ActivityData::ACTIVITY_PRESENT,
      (today - 5.days).to_s => User::ActivityData::NO_ACTIVITY
    })

    User::ActivityLog::UpdateAggregates.(user)

    # Only counts value 2 (ACTIVITY_PRESENT), not 3 (STREAK_FREEZE_USED) or 1 (NO_ACTIVITY)
    assert_equal 2, user.activity_data.reload.total_active_days
  end

  test "does nothing when activity_data is nil" do
    user = create(:user)
    user.activity_data.destroy!
    user.reload

    assert_nothing_raised do
      User::ActivityLog::UpdateAggregates.(user)
    end
  end

  test "handles empty activity_days" do
    user = create(:user)
    user.activity_data.update!(activity_days: {})

    User::ActivityLog::UpdateAggregates.(user)

    assert_equal 0, user.activity_data.reload.current_streak
    assert_equal 0, user.activity_data.reload.total_active_days
  end
end
