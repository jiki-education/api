require "test_helper"

class Stripe::UpdateSubscriptionTest < ActiveSupport::TestCase
  test "switches from monthly to annual with immediate proration" do
    user = create(:user)
    period_end = 1.year.from_now
    user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      subscription_status: "active",
      subscription_interval: "monthly",
      subscription_valid_until: 1.month.from_now
    )

    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription_item = mock
    subscription_item.stubs(:id).returns("si_123")
    subscription.stubs(:items).returns(mock(data: [subscription_item]))

    updated_subscription_item = mock
    updated_subscription_item.stubs(:current_period_end).returns(period_end.to_i)

    updated_subscription = mock
    updated_subscription.stubs(:items).returns(mock(data: [updated_subscription_item]))

    ::Stripe::Subscription.expects(:retrieve).with("sub_123").returns(subscription)
    ::Stripe::Subscription.expects(:update).with(
      "sub_123",
      items: [{ id: "si_123", price: Jiki.config.stripe_premium_annual_price_id }],
      proration_behavior: "always_invoice"
    ).returns(updated_subscription)

    result = Stripe::UpdateSubscription.(user, "annual")

    assert result[:success]
    assert_equal "annual", result[:interval]
    assert_equal "immediate", result[:effective_at]

    user.data.reload
    assert_equal "annual", user.data.subscription_interval
  end

  test "switches from annual to monthly with prorations" do
    user = create(:user)
    period_end = 1.month.from_now
    user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      subscription_status: "active",
      subscription_interval: "annual",
      subscription_valid_until: 1.year.from_now
    )

    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription_item = mock
    subscription_item.stubs(:id).returns("si_123")
    subscription.stubs(:items).returns(mock(data: [subscription_item]))

    updated_subscription_item = mock
    updated_subscription_item.stubs(:current_period_end).returns(period_end.to_i)

    updated_subscription = mock
    updated_subscription.stubs(:items).returns(mock(data: [updated_subscription_item]))

    ::Stripe::Subscription.expects(:retrieve).with("sub_123").returns(subscription)
    ::Stripe::Subscription.expects(:update).with(
      "sub_123",
      items: [{ id: "si_123", price: Jiki.config.stripe_premium_monthly_price_id }],
      proration_behavior: "create_prorations"
    ).returns(updated_subscription)

    result = Stripe::UpdateSubscription.(user, "monthly")

    assert result[:success]
    assert_equal "monthly", result[:interval]

    user.data.reload
    assert_equal "monthly", user.data.subscription_interval
  end

  test "raises ArgumentError when no active subscription" do
    user = create(:user)
    user.data.update!(stripe_subscription_id: nil)

    error = assert_raises(ArgumentError) do
      Stripe::UpdateSubscription.(user, "annual")
    end

    assert_equal "No active subscription", error.message
  end

  test "raises ArgumentError when already on requested interval" do
    user = create(:user)
    user.data.update!(
      stripe_subscription_id: "sub_123",
      subscription_interval: "monthly"
    )

    error = assert_raises(ArgumentError) do
      Stripe::UpdateSubscription.(user, "monthly")
    end

    assert_equal "Already on monthly billing", error.message
  end
end
