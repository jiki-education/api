require "test_helper"

class SerializeUserTest < ActiveSupport::TestCase
  test "serializes user with no Stripe state and no entitlements" do
    user = create(:user, handle: "test_user", email: "test@example.com", name: "Test User",
      avatar_url: "https://example.com/avatar.png")

    assert_equal(
      {
        handle: "test_user",
        premium: false,
        premium_sources: [],
        email: "test@example.com",
        name: "Test User",
        avatar_url: "https://example.com/avatar.png",
        uses_oauth: false,
        email_confirmed: user.confirmed?,
        admin: false,
        subscription_status: "never_subscribed",
        subscription: nil,
        premium_prices: {
          currency: :usd,
          monthly: 999,
          annual: 9900,
          country_code: nil
        }
      },
      SerializeUser.(user)
    )
  end

  test "serializes user with canceled status returns nil subscription" do
    user = create(:user)
    user.data.update!(subscription_status: "canceled")

    result = SerializeUser.(user)

    refute result[:premium]
    assert_equal [], result[:premium_sources]
    assert_equal "canceled", result[:subscription_status]
    assert_nil result[:subscription]
  end

  test "serializes user with active subscription returns subscription object" do
    user = create(:user)
    valid_until = 1.month.from_now
    user.data.update!(
      subscription_status: "active",
      subscription_interval: "monthly",
      subscription_valid_until: valid_until
    )

    result = SerializeUser.(user)

    assert result[:premium]
    assert_equal [PremiumEntitlement::STRIPE], result[:premium_sources]
    assert_equal "active", result[:subscription_status]
    refute_nil result[:subscription]
    assert_equal "monthly", result[:subscription][:interval]
    assert_equal valid_until.iso8601(3), result[:subscription][:subscription_valid_until].iso8601(3)
    refute result[:subscription][:in_grace_period]
    expected_grace_end = valid_until + 7.days
    assert_equal expected_grace_end.iso8601(3), result[:subscription][:grace_period_ends_at].iso8601(3)
  end

  test "serializes user in grace period with correct flags" do
    user = create(:user)
    period_end = 3.days.ago
    user.data.update!(
      subscription_status: "payment_failed",
      stripe_subscription_status: "past_due",
      subscription_valid_until: period_end
    )

    result = SerializeUser.(user)

    assert result[:premium]
    assert_equal [PremiumEntitlement::STRIPE], result[:premium_sources]
    assert_equal "payment_failed", result[:subscription_status]
    refute_nil result[:subscription]
    assert result[:subscription][:in_grace_period]
    refute_nil result[:subscription][:grace_period_ends_at]
    expected_grace_end = period_end + 7.days
    assert_equal expected_grace_end.iso8601(3), result[:subscription][:grace_period_ends_at].iso8601(3)
  end

  test "serializes user with incomplete subscription returns subscription object" do
    user = create(:user)
    user.data.update!(
      subscription_status: "incomplete",
      subscription_valid_until: nil
    )

    result = SerializeUser.(user)

    refute result[:premium]
    assert_equal [], result[:premium_sources]
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
      subscription_status: "cancelling",
      subscription_valid_until: valid_until
    )

    result = SerializeUser.(user)

    assert result[:premium]
    assert_equal [PremiumEntitlement::STRIPE], result[:premium_sources]
    assert_equal "cancelling", result[:subscription_status]
    refute_nil result[:subscription]
    assert_equal valid_until.iso8601(3), result[:subscription][:subscription_valid_until].iso8601(3)
    refute result[:subscription][:in_grace_period]
    expected_grace_end = valid_until + 7.days
    assert_equal expected_grace_end.iso8601(3), result[:subscription][:grace_period_ends_at].iso8601(3)
  end

  test "serializes premium_sources for a user with an Exercism Insider entitlement" do
    user = create(:user)
    create(:premium_entitlement, :insider, user:)

    result = SerializeUser.(user)

    assert result[:premium]
    assert_equal [PremiumEntitlement::EXERCISM_INSIDER], result[:premium_sources]
  end

  test "serializes premium_sources combining Stripe and an entitlement" do
    user = create(:user)
    user.data.update!(subscription_status: "active")
    create(:premium_entitlement, :insider, user:)

    result = SerializeUser.(user)

    assert result[:premium]
    assert_equal [PremiumEntitlement::STRIPE, PremiumEntitlement::EXERCISM_INSIDER], result[:premium_sources]
  end

  test "serializes pricing with local currency for Indian user" do
    user = create(:user)
    user.data.update_column(:country_code, "IN")

    result = SerializeUser.(user)

    assert_equal :inr, result[:premium_prices][:currency]
    assert_equal 19_900, result[:premium_prices][:monthly]
    assert_equal 199_900, result[:premium_prices][:annual]
    assert_equal "IN", result[:premium_prices][:country_code]
  end

  test "serializes uses_oauth: false for password-only user" do
    user = create(:user)

    result = SerializeUser.(user)

    refute result[:uses_oauth]
  end

  test "serializes admin: false for regular user" do
    user = create(:user)

    result = SerializeUser.(user)

    refute result[:admin]
  end

  test "serializes admin: true for admin user" do
    user = create(:user, admin: true)

    result = SerializeUser.(user)

    assert result[:admin]
  end

  test "serializes uses_oauth: true for user linked to Google" do
    user = create(:user, google_id: "google-abc")

    result = SerializeUser.(user)

    assert result[:uses_oauth]
  end

  test "serializes uses_oauth: true for user linked to Exercism" do
    user = create(:user, exercism_id: "1530")

    result = SerializeUser.(user)

    assert result[:uses_oauth]
  end

  test "serializes pricing with USD for user without country" do
    user = create(:user)

    result = SerializeUser.(user)

    assert_equal :usd, result[:premium_prices][:currency]
    assert_equal 999, result[:premium_prices][:monthly]
    assert_equal 9900, result[:premium_prices][:annual]
    assert_nil result[:premium_prices][:country_code]
  end
end
