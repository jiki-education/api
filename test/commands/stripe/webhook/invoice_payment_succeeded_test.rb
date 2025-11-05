require "test_helper"

class Stripe::Webhook::InvoicePaymentSucceededTest < ActiveSupport::TestCase
  test "clears payment failure when payment succeeds" do
    user = create(:user)
    user.data.update!(
      stripe_customer_id: "cus_123",
      stripe_subscription_status: "past_due",
      payment_failed_at: 3.days.ago
    )

    invoice = mock
    invoice.stubs(:customer).returns("cus_123")

    event = mock
    event.stubs(:data).returns(mock(object: invoice))

    Stripe::Webhook::InvoicePaymentSucceeded.(event)

    user.data.reload
    assert_equal "active", user.data.stripe_subscription_status
    assert_nil user.data.payment_failed_at
  end
end
