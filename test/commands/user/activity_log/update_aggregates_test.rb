require "test_helper"

class User::ActivityLog::UpdateAggregatesTest < ActiveSupport::TestCase
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

  test "streak breaks with gaps" do
    user = create(:user)
    today = Date.current
    user.activity_data.update!(activity_days: {
      (today - 5.days).to_s => User::ActivityData::ACTIVITY_PRESENT,
      (today - 4.days).to_s => User::ActivityData::ACTIVITY_PRESENT,
      # Gap on day -3
      (today - 1.day).to_s => User::ActivityData::ACTIVITY_PRESENT,
      today.to_s => User::ActivityData::ACTIVITY_PRESENT
    })

    User::ActivityLog::UpdateAggregates.(user)

    assert_equal 2, user.activity_data.reload.current_streak
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

  test "calculates longest_streak correctly" do
    user = create(:user)
    today = Date.current
    user.activity_data.update!(activity_days: {
      # 5-day streak in the past
      (today - 20.days).to_s => User::ActivityData::ACTIVITY_PRESENT,
      (today - 19.days).to_s => User::ActivityData::ACTIVITY_PRESENT,
      (today - 18.days).to_s => User::ActivityData::ACTIVITY_PRESENT,
      (today - 17.days).to_s => User::ActivityData::ACTIVITY_PRESENT,
      (today - 16.days).to_s => User::ActivityData::ACTIVITY_PRESENT,
      # Current 2-day streak
      (today - 1.day).to_s => User::ActivityData::ACTIVITY_PRESENT,
      today.to_s => User::ActivityData::ACTIVITY_PRESENT
    })

    User::ActivityLog::UpdateAggregates.(user)

    assert_equal 5, user.activity_data.reload.longest_streak
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

  test "only saves when values changed" do
    user = create(:user)
    user.activity_data.update!(
      activity_days: { Date.current.to_s => User::ActivityData::ACTIVITY_PRESENT },
      current_streak: 1,
      longest_streak: 1,
      total_active_days: 1
    )
    original_updated_at = user.activity_data.updated_at

    # Small sleep to ensure time difference if updated
    sleep 0.01

    User::ActivityLog::UpdateAggregates.(user)

    # updated_at should not change since values are the same
    assert_equal original_updated_at, user.activity_data.reload.updated_at
  end

  test "returns early when activity_data is nil" do
    user = create(:user)
    user.activity_data.destroy!
    user.reload

    # Should not raise
    User::ActivityLog::UpdateAggregates.(user)
  end

  test "handles empty activity_days" do
    user = create(:user)
    user.activity_data.update!(activity_days: {})

    User::ActivityLog::UpdateAggregates.(user)

    assert_equal 0, user.activity_data.reload.current_streak
    assert_equal 0, user.activity_data.reload.total_active_days
  end
end
