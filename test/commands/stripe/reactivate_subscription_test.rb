require "test_helper"

class Stripe::ReactivateSubscriptionTest < ActiveSupport::TestCase
  test "reactivates subscription scheduled for cancellation" do
    user = create(:user)
    period_end = 1.month.from_now
    user.data.update!(
      stripe_subscription_id: "sub_123",
      subscription_status: "cancelling",
      subscription_valid_until: period_end
    )

    updated_subscription = mock

    ::Stripe::Subscription.expects(:update).with(
      "sub_123",
      cancel_at_period_end: false
    ).returns(updated_subscription)

    result = Stripe::ReactivateSubscription.(user)

    assert result[:success]
    assert_in_delta period_end.to_i, result[:subscription_valid_until].to_i, 1

    user.data.reload
    assert_equal "active", user.data.subscription_status
  end

  test "raises ArgumentError when no active subscription" do
    user = create(:user)
    user.data.update!(stripe_subscription_id: nil)

    error = assert_raises(ArgumentError) do
      Stripe::ReactivateSubscription.(user)
    end

    assert_equal "No active subscription", error.message
  end

  test "raises ArgumentError when subscription is not scheduled for cancellation" do
    user = create(:user)
    user.data.update!(
      stripe_subscription_id: "sub_123",
      subscription_status: "active"
    )

    error = assert_raises(ArgumentError) do
      Stripe::ReactivateSubscription.(user)
    end

    assert_equal "Subscription is not scheduled for cancellation", error.message
  end
end
