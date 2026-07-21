require "test_helper"

class Stripe::CancelSubscriptionTest < ActiveSupport::TestCase
  test "cancels subscription at period end by default" do
    valid_until = 1.month.from_now.change(usec: 0)
    user = create(:user)
    user.data.update!(
      stripe_subscription_id: "sub_123",
      subscription_status: "active",
      subscription_valid_until: valid_until
    )

    ::Stripe::Subscription.expects(:update).with(
      "sub_123",
      cancel_at_period_end: true
    ).returns(mock)

    result = Stripe::CancelSubscription.(user)

    assert_equal "cancelling", user.data.reload.subscription_status
    assert result[:success]
    assert_equal valid_until, result[:cancels_at]
  end

  test "cancels subscription immediately when cancel_immediately is true" do
    user = create(:user)
    user.data.update!(
      stripe_subscription_id: "sub_123",
      subscription_status: "active"
    )

    ::Stripe::Subscription.expects(:cancel).with("sub_123").returns(mock)

    result = Stripe::CancelSubscription.(user, cancel_immediately: true)

    assert_equal "canceled", user.data.reload.subscription_status
    assert result[:success]
    refute_nil result[:cancels_at]
  end

  test "does nothing when no subscription id" do
    user = create(:user)
    user.data.update!(stripe_subscription_id: nil)

    ::Stripe::Subscription.expects(:update).never
    ::Stripe::Subscription.expects(:cancel).never

    Stripe::CancelSubscription.(user)
  end

  test "handles already deleted subscription gracefully" do
    user = create(:user)
    user.data.update!(stripe_subscription_id: "sub_123", subscription_status: "active")

    error = ::Stripe::InvalidRequestError.new("No such subscription: sub_123", nil)
    ::Stripe::Subscription.expects(:update).raises(error)

    result = Stripe::CancelSubscription.(user)

    assert result[:success]
    assert_equal "canceled", user.data.reload.subscription_status
  end

  test "raises StripeSubscriptionCancellationError on Stripe API error" do
    user = create(:user)
    user.data.update!(stripe_subscription_id: "sub_123")

    error = ::Stripe::APIError.new("API error")
    ::Stripe::Subscription.expects(:update).raises(error)

    assert_raises(StripeSubscriptionCancellationError) do
      Stripe::CancelSubscription.(user)
    end
  end
end
