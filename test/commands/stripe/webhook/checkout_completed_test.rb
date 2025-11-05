require "test_helper"

class Stripe::Webhook::CheckoutCompletedTest < ActiveSupport::TestCase
  test "updates user subscription data when checkout completes" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    session = mock
    session.stubs(:customer).returns("cus_123")
    session.stubs(:subscription).returns("sub_123")

    event = mock
    event.stubs(:data).returns(mock(object: session))

    Stripe::Webhook::CheckoutCompleted.(event)

    user.data.reload
    assert_equal "sub_123", user.data.stripe_subscription_id
    assert_equal "active", user.data.stripe_subscription_status
  end

  test "logs error when user not found" do
    session = mock
    session.stubs(:customer).returns("cus_nonexistent")

    event = mock
    event.stubs(:data).returns(mock(object: session))

    Rails.logger.expects(:error).
      with("Checkout completed but user not found for customer: cus_nonexistent")

    Stripe::Webhook::CheckoutCompleted.(event)
  end
end
