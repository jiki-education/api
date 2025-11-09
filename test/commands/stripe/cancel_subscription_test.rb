require "test_helper"

class Stripe::CancelSubscriptionTest < ActiveSupport::TestCase
  test "cancels subscription at period end" do
    user = create(:user)
    period_end = 1.month.from_now
    user.data.update!(
      stripe_subscription_id: "sub_123",
      subscription_status: "active",
      subscription_valid_until: period_end
    )

    updated_subscription = mock

    ::Stripe::Subscription.expects(:update).with(
      "sub_123",
      cancel_at_period_end: true
    ).returns(updated_subscription)

    result = Stripe::CancelSubscription.(user)

    assert result[:success]
    assert_in_delta period_end.to_i, result[:cancels_at].to_i, 1

    user.data.reload
    assert_equal "cancelling", user.data.subscription_status
  end

  test "raises ArgumentError when no active subscription" do
    user = create(:user)
    user.data.update!(stripe_subscription_id: nil)

    error = assert_raises(ArgumentError) do
      Stripe::CancelSubscription.(user)
    end

    assert_equal "No active subscription", error.message
  end
end
