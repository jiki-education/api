require "test_helper"

class Stripe::CancelSubscriptionImmediatelyTest < ActiveSupport::TestCase
  test "cancels subscription immediately" do
    user = create(:user)
    user.data.update!(
      stripe_subscription_id: "sub_123",
      subscription_status: "active"
    )

    ::Stripe::Subscription.expects(:cancel).with("sub_123").returns(mock)

    Stripe::CancelSubscriptionImmediately.(user)
  end

  test "does nothing when no subscription id" do
    user = create(:user)
    user.data.update!(stripe_subscription_id: nil)

    ::Stripe::Subscription.expects(:cancel).never

    Stripe::CancelSubscriptionImmediately.(user)
  end

  test "handles already deleted subscription gracefully" do
    user = create(:user)
    user.data.update!(stripe_subscription_id: "sub_123")

    error = ::Stripe::InvalidRequestError.new("No such subscription: sub_123", nil)
    ::Stripe::Subscription.expects(:cancel).with("sub_123").raises(error)

    assert_nothing_raised do
      Stripe::CancelSubscriptionImmediately.(user)
    end
  end

  test "raises StripeSubscriptionCancellationError on other InvalidRequestError" do
    user = create(:user)
    user.data.update!(stripe_subscription_id: "sub_123")

    error = ::Stripe::InvalidRequestError.new("Some other error", nil)
    ::Stripe::Subscription.expects(:cancel).with("sub_123").raises(error)

    assert_raises(StripeSubscriptionCancellationError) do
      Stripe::CancelSubscriptionImmediately.(user)
    end
  end

  test "raises StripeSubscriptionCancellationError on Stripe API error" do
    user = create(:user)
    user.data.update!(stripe_subscription_id: "sub_123")

    error = ::Stripe::APIError.new("API error")
    ::Stripe::Subscription.expects(:cancel).with("sub_123").raises(error)

    assert_raises(StripeSubscriptionCancellationError) do
      Stripe::CancelSubscriptionImmediately.(user)
    end
  end
end
