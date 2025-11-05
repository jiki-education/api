require "test_helper"

class Stripe::Webhook::InvoicePaymentFailedTest < ActiveSupport::TestCase
  test "sets payment failure state when payment fails" do
    user = create(:user)
    user.data.update!(
      stripe_customer_id: "cus_123",
      stripe_subscription_status: "active"
    )

    invoice = mock
    invoice.stubs(:customer).returns("cus_123")

    event = mock
    event.stubs(:data).returns(mock(object: invoice))

    Stripe::Webhook::InvoicePaymentFailed.(event)

    user.data.reload
    assert_equal "past_due", user.data.stripe_subscription_status
    refute_nil user.data.payment_failed_at
  end

  test "does not overwrite existing payment_failed_at" do
    original_time = 2.days.ago
    user = create(:user)
    user.data.update!(
      stripe_customer_id: "cus_123",
      stripe_subscription_status: "past_due",
      payment_failed_at: original_time
    )

    invoice = mock
    invoice.stubs(:customer).returns("cus_123")

    event = mock
    event.stubs(:data).returns(mock(object: invoice))

    Stripe::Webhook::InvoicePaymentFailed.(event)

    user.data.reload
    assert_in_delta original_time.to_i, user.data.payment_failed_at.to_i, 1
  end
end
