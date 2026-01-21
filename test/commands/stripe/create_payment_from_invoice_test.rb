require "test_helper"

class Stripe::CreatePaymentFromInvoiceTest < ActiveSupport::TestCase
  test "creates payment record with correct attributes for premium" do
    user = create(:user)
    invoice = mock_invoice
    subscription = mock_subscription(price_id: Jiki.config.stripe_premium_price_id)

    payment = Stripe::CreatePaymentFromInvoice.(user, invoice, subscription)

    assert payment.persisted?
    assert_equal "in_test123", payment.payment_processor_id
    assert_equal 1999, payment.amount_in_cents
    assert_equal "usd", payment.currency
    assert_equal "premium", payment.product
    assert_equal "https://invoice.stripe.com/test", payment.external_receipt_url
    assert_equal "in_test123", payment.data["stripe_invoice_id"]
    assert_equal "ch_456", payment.data["stripe_charge_id"]
    assert_equal "sub_789", payment.data["stripe_subscription_id"]
    assert_equal "cus_abc", payment.data["stripe_customer_id"]
    assert_equal "subscription_create", payment.data["billing_reason"]
    refute_nil payment.data["period_start"]
    refute_nil payment.data["period_end"]
  end

  test "creates payment record with correct attributes for max" do
    user = create(:user)
    invoice = mock_invoice(amount_paid: 4999)
    subscription = mock_subscription(price_id: Jiki.config.stripe_max_price_id)

    payment = Stripe::CreatePaymentFromInvoice.(user, invoice, subscription)

    assert payment.persisted?
    assert_equal "max", payment.product
    assert_equal 4999, payment.amount_in_cents
  end

  test "falls back to user membership type for unknown price id" do
    user = create(:user)
    user.data.update!(membership_type: "max")
    invoice = mock_invoice
    subscription = mock_subscription(price_id: "price_unknown")

    payment = Stripe::CreatePaymentFromInvoice.(user, invoice, subscription)

    assert payment.persisted?
    assert_equal "max", payment.product
  end

  test "falls back to premium for unknown price id when user is premium" do
    user = create(:user)
    user.data.update!(membership_type: "premium")
    invoice = mock_invoice
    subscription = mock_subscription(price_id: "price_unknown")

    payment = Stripe::CreatePaymentFromInvoice.(user, invoice, subscription)

    assert payment.persisted?
    assert_equal "premium", payment.product
  end

  test "falls back to premium for unknown price id when user is standard" do
    user = create(:user)
    user.data.update!(membership_type: "standard")
    invoice = mock_invoice
    subscription = mock_subscription(price_id: "price_unknown")

    payment = Stripe::CreatePaymentFromInvoice.(user, invoice, subscription)

    assert payment.persisted?
    assert_equal "premium", payment.product
  end

  test "returns existing payment for duplicate payment_processor_id" do
    user = create(:user)
    existing_payment = create(:payment, user:, payment_processor_id: "in_test123")

    invoice = mock_invoice
    subscription = mock_subscription

    result = Stripe::CreatePaymentFromInvoice.(user, invoice, subscription)

    assert_equal existing_payment.id, result.id
  end

  test "handles nil subscription gracefully" do
    user = create(:user)
    user.data.update!(membership_type: "premium")
    invoice = mock_invoice(id: "in_nil_sub_test")

    payment = Stripe::CreatePaymentFromInvoice.(user, invoice, nil)

    assert payment.persisted?
    assert_equal "premium", payment.product
    assert_nil payment.data["period_start"]
    assert_nil payment.data["period_end"]
  end

  private
  def mock_invoice(id: "in_test123", amount_paid: 1999)
    invoice = mock
    invoice.stubs(:id).returns(id)
    invoice.stubs(:amount_paid).returns(amount_paid)
    invoice.stubs(:currency).returns("usd")
    invoice.stubs(:hosted_invoice_url).returns("https://invoice.stripe.com/test")
    invoice.stubs(:charge).returns("ch_456")
    invoice.stubs(:subscription).returns("sub_789")
    invoice.stubs(:customer).returns("cus_abc")
    invoice.stubs(:billing_reason).returns("subscription_create")
    invoice
  end

  def mock_subscription(price_id: Jiki.config.stripe_premium_price_id)
    price = mock
    price.stubs(:id).returns(price_id)

    item = mock
    item.stubs(:price).returns(price)
    item.stubs(:current_period_start).returns(1.month.ago.to_i)
    item.stubs(:current_period_end).returns(Time.current.to_i)

    items = mock
    items.stubs(:data).returns([item])

    subscription = mock
    subscription.stubs(:items).returns(items)
    subscription
  end
end
