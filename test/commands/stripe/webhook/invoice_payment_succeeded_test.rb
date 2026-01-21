require "test_helper"

class Stripe::Webhook::InvoicePaymentSucceededTest < ActiveSupport::TestCase
  test "calls UpdateSubscriptionsFromInvoice with correct args" do
    user = create(:user)
    period_end = 1.month.from_now
    user.data.update!(stripe_customer_id: "cus_123", membership_type: "premium")

    invoice = mock_invoice
    subscription = mock_subscription(period_end:)
    event = mock_event(invoice)

    Stripe::Subscription.expects(:retrieve).with("sub_123").returns(subscription)
    Stripe::UpdateSubscriptionsFromInvoice.expects(:call).with(user, invoice, subscription)
    Stripe::CreatePaymentFromInvoice.expects(:call).with(user, invoice, subscription)

    Stripe::Webhook::InvoicePaymentSucceeded.(event)
  end

  test "calls CreatePaymentFromInvoice with correct args" do
    user = create(:user)
    period_end = 1.month.from_now
    user.data.update!(stripe_customer_id: "cus_123", membership_type: "premium")

    invoice = mock_invoice
    subscription = mock_subscription(period_end:)
    event = mock_event(invoice)

    Stripe::Subscription.expects(:retrieve).with("sub_123").returns(subscription)
    Stripe::UpdateSubscriptionsFromInvoice.stubs(:call)
    Stripe::CreatePaymentFromInvoice.expects(:call).with(user, invoice, subscription)

    Stripe::Webhook::InvoicePaymentSucceeded.(event)
  end

  test "updates user data to active status" do
    user = create(:user)
    period_end = 1.month.from_now
    user.data.update!(
      stripe_customer_id: "cus_123",
      stripe_subscription_status: "past_due",
      subscription_status: "payment_failed",
      subscription_valid_until: 1.week.ago,
      membership_type: "premium"
    )

    invoice = mock_invoice
    subscription = mock_subscription(period_end:)
    event = mock_event(invoice)

    Stripe::Subscription.expects(:retrieve).with("sub_123").returns(subscription)
    Stripe::UpdateSubscriptionsFromInvoice.stubs(:call)
    Stripe::CreatePaymentFromInvoice.stubs(:call)

    Stripe::Webhook::InvoicePaymentSucceeded.(event)

    user.data.reload
    assert_equal "active", user.data.stripe_subscription_status
    assert_equal "active", user.data.subscription_status
    assert_in_delta period_end.to_i, user.data.subscription_valid_until.to_i, 1
  end

  test "returns early if user not found" do
    invoice = mock
    invoice.stubs(:customer).returns("cus_nonexistent")
    event = mock_event(invoice)

    Stripe::UpdateSubscriptionsFromInvoice.expects(:call).never
    Stripe::CreatePaymentFromInvoice.expects(:call).never

    Stripe::Webhook::InvoicePaymentSucceeded.(event)
  end

  test "returns early if invoice has no subscription" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    invoice = mock
    invoice.stubs(:customer).returns("cus_123")
    invoice.stubs(:subscription).returns(nil)
    event = mock_event(invoice)

    Stripe::UpdateSubscriptionsFromInvoice.expects(:call).never
    Stripe::CreatePaymentFromInvoice.expects(:call).never

    Stripe::Webhook::InvoicePaymentSucceeded.(event)
  end

  test "returns early if subscription item has no period end" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    invoice = mock_invoice
    subscription = mock_subscription_without_period_end
    event = mock_event(invoice)

    Stripe::Subscription.expects(:retrieve).with("sub_123").returns(subscription)
    Stripe::UpdateSubscriptionsFromInvoice.expects(:call).never
    Stripe::CreatePaymentFromInvoice.expects(:call).never

    Stripe::Webhook::InvoicePaymentSucceeded.(event)
  end

  test "wraps operations in transaction" do
    user = create(:user)
    period_end = 1.month.from_now
    user.data.update!(stripe_customer_id: "cus_123", membership_type: "premium")

    invoice = mock_invoice
    subscription = mock_subscription(period_end:)
    event = mock_event(invoice)

    Stripe::Subscription.expects(:retrieve).with("sub_123").returns(subscription)
    Stripe::UpdateSubscriptionsFromInvoice.stubs(:call)
    Stripe::CreatePaymentFromInvoice.stubs(:call).raises(StandardError.new("Payment creation failed"))

    assert_raises(StandardError) do
      Stripe::Webhook::InvoicePaymentSucceeded.(event)
    end

    # User data should not be updated due to transaction rollback
    user.data.reload
    refute_equal "active", user.data.subscription_status
  end

  private
  def mock_invoice
    invoice = mock
    invoice.stubs(:customer).returns("cus_123")
    invoice.stubs(:subscription).returns("sub_123")
    invoice
  end

  def mock_subscription(period_end: 1.month.from_now)
    item = mock
    item.stubs(:current_period_end).returns(period_end.to_i)

    items = mock
    items.stubs(:data).returns([item])

    subscription = mock
    subscription.stubs(:items).returns(items)
    subscription
  end

  def mock_subscription_without_period_end
    item = mock
    item.stubs(:current_period_end).returns(nil)

    items = mock
    items.stubs(:data).returns([item])

    subscription = mock
    subscription.stubs(:items).returns(items)
    subscription
  end

  def mock_event(invoice)
    event = mock
    event.stubs(:data).returns(mock(object: invoice))
    event
  end
end
