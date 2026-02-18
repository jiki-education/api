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
    assert_equal "usd", result[:premium_prices][:currency]
    assert_equal 999, result[:premium_prices][:monthly]
    assert_equal 9900, result[:premium_prices][:annual]
    assert_nil result[:premium_prices][:country_code]
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
      subscription_interval: "monthly",
      subscription_valid_until: valid_until
    )

    result = SerializeUser.(user)

    assert_equal "premium", result[:membership_type]
    assert_equal "active", result[:subscription_status]
    refute_nil result[:subscription]
    assert_equal "monthly", result[:subscription][:interval]
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
      membership_type: "premium",
      subscription_status: "payment_failed",
      subscription_valid_until: period_end
    )

    result = SerializeUser.(user)

    assert_equal "premium", result[:membership_type]
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

  test "serializes pricing with local currency for Indian user" do
    user = create(:user)
    user.data.update_column(:country_code, "IN")

    result = SerializeUser.(user)

    assert_equal "inr", result[:premium_prices][:currency]
    assert_equal 19_900, result[:premium_prices][:monthly]
    assert_equal 199_900, result[:premium_prices][:annual]
    assert_equal "IN", result[:premium_prices][:country_code]
  end

  test "serializes pricing with USD for user without country" do
    user = create(:user)

    result = SerializeUser.(user)

    assert_equal "usd", result[:premium_prices][:currency]
    assert_equal 999, result[:premium_prices][:monthly]
    assert_equal 9900, result[:premium_prices][:annual]
    assert_nil result[:premium_prices][:country_code]
  end
end
