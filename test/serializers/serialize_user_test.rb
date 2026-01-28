require "test_helper"

class SerializeUserTest < ActiveSupport::TestCase
  test "serializes user with standard membership and never_subscribed status" do
    user = create(:user, handle: "test_user", email: "test@example.com", name: "Test User")

    result = SerializeUser.(user)

    assert_equal "test_user", result[:handle]
    assert_equal "standard", result[:membership_type]
    assert_equal "test@example.com", result[:email]
    assert_equal "Test User", result[:name]
    assert_equal "never_subscribed", result[:subscription_status]
    assert_nil result[:subscription]
  end

  test "serializes user with canceled status returns nil subscription" do
    user = create(:user)
    user.data.update!(
      membership_type: "standard",
      subscription_status: "canceled"
    )

    result = SerializeUser.(user)

    assert_equal "standard", result[:membership_type]
    assert_equal "canceled", result[:subscription_status]
    assert_nil result[:subscription]
  end

  test "serializes user with active subscription returns subscription object" do
    user = create(:user)
    valid_until = 1.month.from_now
    user.data.update!(
      membership_type: "premium",
      subscription_status: "active",
      subscription_valid_until: valid_until
    )

    result = SerializeUser.(user)

    assert_equal "premium", result[:membership_type]
    assert_equal "active", result[:subscription_status]
    refute_nil result[:subscription]
    assert_equal valid_until.iso8601(3), result[:subscription][:subscription_valid_until].iso8601(3)
    refute result[:subscription][:in_grace_period]
    # grace_period_ends_at is present whenever subscription_valid_until is present
    expected_grace_end = valid_until + 7.days
    assert_equal expected_grace_end.iso8601(3), result[:subscription][:grace_period_ends_at].iso8601(3)
  end

  test "serializes user in grace period with correct flags" do
    user = create(:user)
    period_end = 3.days.ago # Expired but within 7-day grace period
    user.data.update!(
      membership_type: "max",
      subscription_status: "payment_failed",
      subscription_valid_until: period_end
    )

    result = SerializeUser.(user)

    assert_equal "max", result[:membership_type]
    assert_equal "payment_failed", result[:subscription_status]
    refute_nil result[:subscription]
    assert result[:subscription][:in_grace_period]
    refute_nil result[:subscription][:grace_period_ends_at]
    # Grace period should be 7 days after subscription_valid_until
    expected_grace_end = period_end + 7.days
    assert_equal expected_grace_end.iso8601(3), result[:subscription][:grace_period_ends_at].iso8601(3)
  end

  test "serializes user with incomplete subscription returns subscription object" do
    user = create(:user)
    user.data.update!(
      membership_type: "standard",
      subscription_status: "incomplete",
      subscription_valid_until: nil
    )

    result = SerializeUser.(user)

    assert_equal "standard", result[:membership_type]
    assert_equal "incomplete", result[:subscription_status]
    refute_nil result[:subscription]
    assert_nil result[:subscription][:subscription_valid_until]
    refute result[:subscription][:in_grace_period]
    assert_nil result[:subscription][:grace_period_ends_at]
  end

  test "serializes user with cancelling subscription returns subscription object" do
    user = create(:user)
    valid_until = 2.weeks.from_now
    user.data.update!(
      membership_type: "premium",
      subscription_status: "cancelling",
      subscription_valid_until: valid_until
    )

    result = SerializeUser.(user)

    assert_equal "premium", result[:membership_type]
    assert_equal "cancelling", result[:subscription_status]
    refute_nil result[:subscription]
    assert_equal valid_until.iso8601(3), result[:subscription][:subscription_valid_until].iso8601(3)
    refute result[:subscription][:in_grace_period]
    # grace_period_ends_at is present whenever subscription_valid_until is present
    expected_grace_end = valid_until + 7.days
    assert_equal expected_grace_end.iso8601(3), result[:subscription][:grace_period_ends_at].iso8601(3)
  end

  test "serializes streaks_enabled" do
    user = create(:user)
    user.data.update!(streaks_enabled: true)

    result = SerializeUser.(user)

    assert result[:streaks_enabled]
  end

  test "includes current_streak when streaks_enabled is true" do
    user = create(:user)
    user.data.update!(streaks_enabled: true)
    user.activity_data.update!(current_streak: 5)

    result = SerializeUser.(user)

    assert_equal 5, result[:current_streak]
    refute result.key?(:total_active_days)
  end

  test "includes total_active_days when streaks_enabled is false" do
    user = create(:user)
    user.data.update!(streaks_enabled: false)
    user.activity_data.update!(total_active_days: 10)

    result = SerializeUser.(user)

    assert_equal 10, result[:total_active_days]
    refute result.key?(:current_streak)
  end
end
