require "test_helper"

class Stripe::Webhook::SubscriptionDeletedTest < ActiveSupport::TestCase
  test "downgrades user to standard when subscription deleted" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      stripe_subscription_status: "active"
    )

    subscription = mock
    subscription.stubs(:id).returns("sub_123")

    event = mock
    event.stubs(:data).returns(mock(object: subscription))

    Stripe::Webhook::SubscriptionDeleted.(event)

    user.data.reload
    assert_equal "standard", user.data.membership_type
    assert_equal "canceled", user.data.stripe_subscription_status
    assert_nil user.data.stripe_subscription_id
    assert_nil user.data.subscription_current_period_end
  end
end
