require "test_helper"

class Stripe::Webhook::SubscriptionDeletedTest < ActiveSupport::TestCase
  test "downgrades user to standard when subscription deleted normally" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      stripe_subscription_status: "active",
      subscription_status: "active",
      subscription_valid_until: 1.month.from_now,
      subscriptions: [{
        stripe_subscription_id: "sub_123",
        tier: "premium",
        started_at: 1.month.ago.iso8601,
        ended_at: nil,
        end_reason: nil,
        payment_failed_at: nil
      }]
    )

    subscription = mock
    subscription.stubs(:id).returns("sub_123")

    event = mock
    event.stubs(:data).returns(mock(object: subscription))

    Stripe::Webhook::SubscriptionDeleted.(event)

    user.data.reload
    assert_equal "standard", user.data.membership_type
    assert_equal "canceled", user.data.stripe_subscription_status
    assert_equal "canceled", user.data.subscription_status
    assert_nil user.data.stripe_subscription_id
    assert_nil user.data.subscription_valid_until

    # Check subscriptions array updated with end_reason
    sub_entry = user.data.subscriptions.first
    refute_nil sub_entry["ended_at"]
    assert_equal "canceled", sub_entry["end_reason"]
  end

  test "records payment_failed end_reason when subscription deleted due to payment failure" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      stripe_subscription_status: "past_due",
      subscription_status: "payment_failed",
      subscriptions: [{
        stripe_subscription_id: "sub_123",
        tier: "premium",
        started_at: 1.month.ago.iso8601,
        ended_at: nil,
        end_reason: nil,
        payment_failed_at: 3.days.ago.iso8601
      }]
    )

    subscription = mock
    subscription.stubs(:id).returns("sub_123")

    event = mock
    event.stubs(:data).returns(mock(object: subscription))

    Stripe::Webhook::SubscriptionDeleted.(event)

    user.data.reload
    # Check subscriptions array updated with payment_failed end_reason
    sub_entry = user.data.subscriptions.first
    assert_equal "payment_failed", sub_entry["end_reason"]
  end

  test "records payment_failed end_reason when subscription deleted in unpaid state" do
    user = create(:user)
    user.data.update!(
      membership_type: "standard",
      stripe_subscription_id: "sub_123",
      stripe_subscription_status: "unpaid",
      subscription_status: "payment_failed",
      subscriptions: [{
        stripe_subscription_id: "sub_123",
        tier: "premium",
        started_at: 1.month.ago.iso8601,
        ended_at: nil,
        end_reason: nil,
        payment_failed_at: 10.days.ago.iso8601
      }]
    )

    subscription = mock
    subscription.stubs(:id).returns("sub_123")

    event = mock
    event.stubs(:data).returns(mock(object: subscription))

    Stripe::Webhook::SubscriptionDeleted.(event)

    user.data.reload
    sub_entry = user.data.subscriptions.first
    assert_equal "payment_failed", sub_entry["end_reason"]
  end
end
