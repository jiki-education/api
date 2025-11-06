require "test_helper"

class Stripe::Webhook::InvoicePaymentSucceededTest < ActiveSupport::TestCase
  test "clears payment failure when payment succeeds" do
    user = create(:user)
    period_end = 1.month.from_now
    user.data.update!(
      stripe_customer_id: "cus_123",
      stripe_subscription_id: "sub_123",
      stripe_subscription_status: "past_due",
      subscription_status: "payment_failed",
      subscription_valid_until: 1.week.ago,
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
    subscription.stubs(:current_period_end).returns(period_end.to_i)

    invoice = mock
    invoice.stubs(:customer).returns("cus_123")
    invoice.stubs(:subscription).returns("sub_123")

    event = mock
    event.stubs(:data).returns(mock(object: invoice))

    Stripe::Subscription.expects(:retrieve).with("sub_123").returns(subscription)

    Stripe::Webhook::InvoicePaymentSucceeded.(event)

    user.data.reload
    assert_equal "active", user.data.stripe_subscription_status
    assert_equal "active", user.data.subscription_status
    assert_in_delta period_end.to_i, user.data.subscription_valid_until.to_i, 1

    # Check payment_failed_at cleared in subscriptions array
    sub_entry = user.data.subscriptions.first
    assert_nil sub_entry["payment_failed_at"]
  end

  test "creates subscription entry for incomplete subscription on first payment" do
    user = create(:user)
    period_end = 1.month.from_now
    user.data.update!(
      stripe_customer_id: "cus_123",
      stripe_subscription_id: "sub_123",
      stripe_subscription_status: "incomplete",
      subscription_status: "incomplete",
      membership_type: "premium",
      subscriptions: []
    )

    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:current_period_end).returns(period_end.to_i)

    invoice = mock
    invoice.stubs(:customer).returns("cus_123")
    invoice.stubs(:subscription).returns("sub_123")

    event = mock
    event.stubs(:data).returns(mock(object: invoice))

    Stripe::Subscription.expects(:retrieve).with("sub_123").returns(subscription).once

    Stripe::Webhook::InvoicePaymentSucceeded.(event)

    user.data.reload
    assert_equal "active", user.data.subscription_status

    # Should create subscription entry
    assert_equal 1, user.data.subscriptions.length
    sub_entry = user.data.subscriptions.first
    assert_equal "sub_123", sub_entry["stripe_subscription_id"]
    assert_equal "premium", sub_entry["tier"]
  end

  test "returns early if invoice has no subscription" do
    user = create(:user)
    user.data.update!(
      stripe_customer_id: "cus_123",
      subscription_status: "payment_failed"
    )

    invoice = mock
    invoice.stubs(:customer).returns("cus_123")
    invoice.stubs(:subscription).returns(nil)

    event = mock
    event.stubs(:data).returns(mock(object: invoice))

    Stripe::Webhook::InvoicePaymentSucceeded.(event)

    user.data.reload
    # Should not change status if no subscription
    assert_equal "payment_failed", user.data.subscription_status
  end
end
