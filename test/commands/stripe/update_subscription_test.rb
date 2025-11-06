require "test_helper"

class Stripe::UpdateSubscriptionTest < ActiveSupport::TestCase
  test "upgrades from premium to max with immediate proration" do
    user = create(:user)
    period_end = 1.month.from_now
    user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      subscription_status: "active",
      subscription_valid_until: period_end
    )

    # Mock Stripe subscription
    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription_item = mock
    subscription_item.stubs(:id).returns("si_123")
    subscription.stubs(:items).returns(mock(data: [subscription_item]))

    updated_subscription = mock
    updated_subscription.stubs(:current_period_end).returns((period_end + 1.day).to_i)

    ::Stripe::Subscription.expects(:retrieve).with("sub_123").returns(subscription)
    ::Stripe::Subscription.expects(:update).with(
      "sub_123",
      items: [{ id: "si_123", price: Jiki.config.stripe_max_price_id }],
      proration_behavior: "always_invoice"
    ).returns(updated_subscription)

    result = Stripe::UpdateSubscription.(user, "max")

    assert result[:success]
    assert_equal "max", result[:tier]
    assert_equal "immediate", result[:effective_at]

    user.data.reload
    assert_equal "max", user.data.membership_type
  end

  test "downgrades from max to premium with immediate proration" do
    user = create(:user)
    period_end = 1.month.from_now
    user.data.update!(
      membership_type: "max",
      stripe_subscription_id: "sub_123",
      subscription_status: "active",
      subscription_valid_until: period_end
    )

    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription_item = mock
    subscription_item.stubs(:id).returns("si_123")
    subscription.stubs(:items).returns(mock(data: [subscription_item]))

    updated_subscription = mock
    updated_subscription.stubs(:current_period_end).returns(period_end.to_i)

    ::Stripe::Subscription.expects(:retrieve).with("sub_123").returns(subscription)
    ::Stripe::Subscription.expects(:update).with(
      "sub_123",
      items: [{ id: "si_123", price: Jiki.config.stripe_premium_price_id }],
      proration_behavior: "create_prorations"
    ).returns(updated_subscription)

    result = Stripe::UpdateSubscription.(user, "premium")

    assert result[:success]
    assert_equal "premium", result[:tier]

    user.data.reload
    assert_equal "premium", user.data.membership_type
  end

  test "raises ArgumentError when no active subscription" do
    user = create(:user)
    user.data.update!(stripe_subscription_id: nil)

    error = assert_raises(ArgumentError) do
      Stripe::UpdateSubscription.(user, "max")
    end

    assert_equal "No active subscription", error.message
  end

  test "raises ArgumentError when already on requested tier" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123"
    )

    error = assert_raises(ArgumentError) do
      Stripe::UpdateSubscription.(user, "premium")
    end

    assert_equal "Already on premium tier", error.message
  end
end
