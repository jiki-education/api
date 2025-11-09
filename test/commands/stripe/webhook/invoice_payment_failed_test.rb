require "test_helper"

class Stripe::Webhook::InvoicePaymentFailedTest < ActiveSupport::TestCase
  test "sets payment failure state when payment fails" do
    user = create(:user)
    period_end = 1.month.from_now
    user.data.update!(
      stripe_customer_id: "cus_123",
      stripe_subscription_id: "sub_123",
      stripe_subscription_status: "active",
      subscription_status: "active",
      subscription_valid_until: period_end,
      subscriptions: [{
        stripe_subscription_id: "sub_123",
        tier: "premium",
        started_at: 1.month.ago.iso8601,
        ended_at: nil,
        end_reason: nil,
        payment_failed_at: nil
      }]
    )

    invoice = mock
    invoice.stubs(:customer).returns("cus_123")
    invoice.stubs(:subscription).returns("sub_123")

    event = mock
    event.stubs(:data).returns(mock(object: invoice))

    Stripe::Webhook::InvoicePaymentFailed.(event)

    user.data.reload
    assert_equal "past_due", user.data.stripe_subscription_status
    assert_equal "payment_failed", user.data.subscription_status

    # subscription_valid_until should NOT be extended - stays at original period_end
    assert_in_delta period_end.to_i, user.data.subscription_valid_until.to_i, 1

    # Check payment_failed_at in subscriptions array
    sub_entry = user.data.subscriptions.first
    refute_nil sub_entry["payment_failed_at"]
  end

  test "does not overwrite existing payment_failed_at in subscriptions array" do
    original_time = 2.days.ago
    period_end = 1.week.from_now
    user = create(:user)
    user.data.update!(
      stripe_customer_id: "cus_123",
      stripe_subscription_id: "sub_123",
      stripe_subscription_status: "past_due",
      subscription_status: "payment_failed",
      subscription_valid_until: period_end,
      subscriptions: [{
        stripe_subscription_id: "sub_123",
        tier: "premium",
        started_at: 1.month.ago.iso8601,
        ended_at: nil,
        end_reason: nil,
        payment_failed_at: original_time.iso8601
      }]
    )

    invoice = mock
    invoice.stubs(:customer).returns("cus_123")
    invoice.stubs(:subscription).returns("sub_123")

    event = mock
    event.stubs(:data).returns(mock(object: invoice))

    Stripe::Webhook::InvoicePaymentFailed.(event)

    user.data.reload
    sub_entry = user.data.subscriptions.first
    assert_in_delta original_time.to_i, Time.parse(sub_entry["payment_failed_at"]).to_i, 1
  end

  test "returns early if invoice has no subscription" do
    user = create(:user)
    user.data.update!(
      stripe_customer_id: "cus_123",
      subscription_status: "active"
    )

    invoice = mock
    invoice.stubs(:customer).returns("cus_123")
    invoice.stubs(:subscription).returns(nil)

    event = mock
    event.stubs(:data).returns(mock(object: invoice))

    Stripe::Webhook::InvoicePaymentFailed.(event)

    user.data.reload
    # Should not change status if no subscription
    assert_equal "active", user.data.subscription_status
  end
end
