require "test_helper"

class User::DataTest < ActiveSupport::TestCase
  test "standard? returns true for standard membership" do
    user = create(:user)
    user.data.update!(membership_type: "standard")
    assert user.data.standard?
    refute user.data.premium?
    refute user.data.max?
  end

  test "premium? returns true for premium membership" do
    user = create(:user)
    user.data.update!(membership_type: "premium")
    refute user.data.standard?
    assert user.data.premium?
    refute user.data.max?
  end

  test "max? returns true for max membership" do
    user = create(:user)
    user.data.update!(membership_type: "max")
    refute user.data.standard?
    refute user.data.premium?
    assert user.data.max?
  end

  test "subscription_paid? returns true for standard tier" do
    user = create(:user)
    user.data.update!(membership_type: "standard")
    assert user.data.subscription_paid?
  end

  test "subscription_paid? returns true for active subscription" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      stripe_subscription_status: "active"
    )
    assert user.data.subscription_paid?
  end

  test "subscription_paid? returns true for trialing subscription" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      stripe_subscription_status: "trialing"
    )
    assert user.data.subscription_paid?
  end

  test "subscription_paid? returns false for past_due subscription" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      stripe_subscription_status: "past_due"
    )
    refute user.data.subscription_paid?
  end

  test "subscription_paid? returns false for canceled subscription" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      stripe_subscription_status: "canceled"
    )
    refute user.data.subscription_paid?
  end

  test "subscription_paid? returns false when no subscription status" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      stripe_subscription_status: nil
    )
    refute user.data.subscription_paid?
  end

  test "in_grace_period? returns false when subscription is paid" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      stripe_subscription_status: "active",
      payment_failed_at: 3.days.ago
    )
    refute user.data.in_grace_period?
  end

  test "in_grace_period? returns false when no payment_failed_at" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      stripe_subscription_status: "past_due",
      payment_failed_at: nil
    )
    refute user.data.in_grace_period?
  end

  test "in_grace_period? returns true when payment failed within last week" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      stripe_subscription_status: "past_due",
      payment_failed_at: 3.days.ago
    )
    assert user.data.in_grace_period?
  end

  test "in_grace_period? returns false when payment failed over a week ago" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      stripe_subscription_status: "past_due",
      payment_failed_at: 8.days.ago
    )
    refute user.data.in_grace_period?
  end

  test "grace_period_ends_at returns nil when not in grace period" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      stripe_subscription_status: "active"
    )
    assert_nil user.data.grace_period_ends_at
  end

  test "grace_period_ends_at returns correct date when in grace period" do
    payment_failed = 3.days.ago
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      stripe_subscription_status: "past_due",
      payment_failed_at: payment_failed
    )

    expected_end = payment_failed + 1.week
    assert_in_delta expected_end.to_i, user.data.grace_period_ends_at.to_i, 1
  end

  test "has_premium_access? returns false for standard" do
    user = create(:user)
    user.data.update!(membership_type: "standard")
    refute user.data.has_premium_access?
  end

  test "has_premium_access? returns true for premium" do
    user = create(:user)
    user.data.update!(membership_type: "premium")
    assert user.data.has_premium_access?
  end

  test "has_premium_access? returns true for max" do
    user = create(:user)
    user.data.update!(membership_type: "max")
    assert user.data.has_premium_access?
  end

  test "has_max_access? returns false for standard" do
    user = create(:user)
    user.data.update!(membership_type: "standard")
    refute user.data.has_max_access?
  end

  test "has_max_access? returns false for premium" do
    user = create(:user)
    user.data.update!(membership_type: "premium")
    refute user.data.has_max_access?
  end

  test "has_max_access? returns true for max" do
    user = create(:user)
    user.data.update!(membership_type: "max")
    assert user.data.has_max_access?
  end
end
