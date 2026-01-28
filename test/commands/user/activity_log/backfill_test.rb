require "test_helper"

class User::ActivityLog::BackfillTest < ActiveSupport::TestCase
  test "fills missing days between last recorded day and today with NO_ACTIVITY" do
    user = create(:user)
    today = Date.current
    last_recorded = today - 5.days

    user.activity_data.update!(activity_days: {
      last_recorded.to_s => User::ActivityData::ACTIVITY_PRESENT
    })

    User::ActivityLog::Backfill.(user)

    activity_days = user.activity_data.reload.activity_days

    # Should fill days -4, -3, -2, -1 (not today)
    assert_equal User::ActivityData::NO_ACTIVITY, activity_days[(today - 4.days).to_s]
    assert_equal User::ActivityData::NO_ACTIVITY, activity_days[(today - 3.days).to_s]
    assert_equal User::ActivityData::NO_ACTIVITY, activity_days[(today - 2.days).to_s]
    assert_equal User::ActivityData::NO_ACTIVITY, activity_days[(today - 1.day).to_s]

    # Should not fill today
    assert_nil activity_days[today.to_s]

    # Should preserve original activity
    assert_equal User::ActivityData::ACTIVITY_PRESENT, activity_days[last_recorded.to_s]
  end

  test "does not overwrite existing activity_days entries" do
    user = create(:user)
    today = Date.current

    # Last recorded date is today - 3.days
    # Backfill should fill from (today - 3.days + 1) to yesterday
    user.activity_data.update!(activity_days: {
      (today - 5.days).to_s => User::ActivityData::ACTIVITY_PRESENT,
      (today - 3.days).to_s => User::ActivityData::STREAK_FREEZE_USED
    })

    User::ActivityLog::Backfill.(user)

    activity_days = user.activity_data.reload.activity_days

    # Should preserve existing entries
    assert_equal User::ActivityData::ACTIVITY_PRESENT, activity_days[(today - 5.days).to_s]
    assert_equal User::ActivityData::STREAK_FREEZE_USED, activity_days[(today - 3.days).to_s]

    # Gap before last recorded date is NOT filled (Backfill only fills forward)
    assert_nil activity_days[(today - 4.days).to_s]

    # Should fill from last recorded date to yesterday
    assert_equal User::ActivityData::NO_ACTIVITY, activity_days[(today - 2.days).to_s]
    assert_equal User::ActivityData::NO_ACTIVITY, activity_days[(today - 1.day).to_s]
  end

  test "calls UpdateAggregates after filling" do
    user = create(:user)
    today = Date.current

    user.activity_data.update!(
      activity_days: { (today - 3.days).to_s => User::ActivityData::ACTIVITY_PRESENT },
      current_streak: 1
    )

    User::ActivityLog::Backfill.(user)

    # After backfill, streak should be recalculated
    # Since there are now NO_ACTIVITY days between the activity and today,
    # current streak should be 0
    assert_equal 0, user.activity_data.reload.current_streak
  end

  test "returns early when activity_days is empty" do
    user = create(:user)
    user.activity_data.update!(activity_days: {})

    # Should not raise
    User::ActivityLog::Backfill.(user)

    assert_empty(user.activity_data.reload.activity_days)
  end

  test "returns early when activity_data is nil" do
    user = create(:user)
    user.activity_data.destroy!
    user.reload

    # Should not raise
    User::ActivityLog::Backfill.(user)
  end

  test "does nothing when last recorded day is yesterday" do
    user = create(:user)
    yesterday = Date.current - 1.day

    user.activity_data.update!(activity_days: {
      yesterday.to_s => User::ActivityData::ACTIVITY_PRESENT
    })

    User::ActivityLog::Backfill.(user)

    activity_days = user.activity_data.reload.activity_days

    # Should only have yesterday's entry
    assert_equal 1, activity_days.keys.count
    assert_equal User::ActivityData::ACTIVITY_PRESENT, activity_days[yesterday.to_s]
  end
end
