require "test_helper"

class Stripe::FulfillPurchaseTest < ActiveSupport::TestCase
  test "records the payment and grants the stripe entitlement" do
    user = create(:user)
    stub_payment_intent

    User::PremiumEntitlement::Grant.expects(:call).with(user, PremiumEntitlement::STRIPE_PURCHASE)

    Stripe::FulfillPurchase.(user, "pi_123")

    payment = user.payments.sole
    assert_equal "pi_123", payment.payment_processor_id
    assert_equal 2399, payment.amount_in_cents
    assert_equal "gbp", payment.currency
    assert_equal "premium", payment.product
    assert_equal "https://pay.stripe.com/receipts/abc", payment.external_receipt_url
    assert_equal(
      {
        "purchase_type" => "lifetime",
        "stripe_payment_intent_id" => "pi_123",
        "stripe_charge_id" => "ch_123",
        "stripe_customer_id" => "cus_123"
      },
      payment.data
    )
  end

  test "clears the pending purchase" do
    user = create(:user)
    user.data.update!(pending_premium_purchase_payment_intent_id: "pi_123", pending_premium_purchase_at: 1.day.ago)
    stub_payment_intent

    Stripe::FulfillPurchase.(user, "pi_123")

    refute user.data.reload.premium_purchase_pending?
  end

  test "clears the pending purchase even when the charge was already refunded" do
    user = create(:user)
    user.data.update!(pending_premium_purchase_payment_intent_id: "pi_123", pending_premium_purchase_at: 1.day.ago)
    stub_payment_intent(refunded: true)

    Stripe::FulfillPurchase.(user, "pi_123")

    refute user.data.reload.premium_purchase_pending?
    refute user.premium?
  end

  test "keeps the pending purchase when the payment intent has not succeeded" do
    user = create(:user)
    user.data.update!(pending_premium_purchase_payment_intent_id: "pi_123", pending_premium_purchase_at: 1.day.ago)
    stub_payment_intent(status: "processing")

    assert_raises(ArgumentError) { Stripe::FulfillPurchase.(user, "pi_123") }
    assert user.data.reload.premium_purchase_pending?
  end

  test "upgrades the user to premium" do
    user = create(:user)
    stub_payment_intent

    Stripe::FulfillPurchase.(user, "pi_123")

    assert user.reload.premium?
    assert user.data.lifetime_premium?
  end

  test "is idempotent" do
    user = create(:user)
    stub_payment_intent

    Stripe::FulfillPurchase.(user, "pi_123")
    Stripe::FulfillPurchase.(user, "pi_123")

    assert_equal 1, user.payments.count
    assert_equal 1, user.premium_entitlements.count
  end

  test "does not refetch the payment intent once the payment is recorded" do
    user = create(:user)
    create(:payment, :lifetime, user:, payment_processor_id: "pi_123")

    ::Stripe::PaymentIntent.expects(:retrieve).never
    User::PremiumEntitlement::Grant.expects(:call).with(user, PremiumEntitlement::STRIPE_PURCHASE)

    Stripe::FulfillPurchase.(user, "pi_123")
  end

  test "does not grant for a revoked payment" do
    user = create(:user)
    payment = create(:payment, :lifetime, user:, payment_processor_id: "pi_123")
    payment.update!(data: payment.data.merge("revoked_at" => Time.current.iso8601))

    User::PremiumEntitlement::Grant.expects(:call).never

    Stripe::FulfillPurchase.(user, "pi_123")
  end

  test "records but does not grant when the charge was already refunded" do
    user = create(:user)
    stub_payment_intent(refunded: true)

    User::PremiumEntitlement::Grant.expects(:call).never

    Stripe::FulfillPurchase.(user, "pi_123")

    payment = user.payments.sole
    assert_equal "refunded", payment.data["revoked_reason"]
    refute_nil payment.data["revoked_at"]
  end

  test "records but does not grant when the charge was already disputed" do
    user = create(:user)
    stub_payment_intent(disputed: true)

    User::PremiumEntitlement::Grant.expects(:call).never

    Stripe::FulfillPurchase.(user, "pi_123")

    assert_equal "disputed", user.payments.sole.data["revoked_reason"]
  end

  test "raises when the payment intent has not succeeded" do
    user = create(:user)
    stub_payment_intent(status: "processing")

    assert_raises(ArgumentError) { Stripe::FulfillPurchase.(user, "pi_123") }
    assert_empty user.payments
  end

  test "tolerates a concurrent fulfilment creating the entitlement first" do
    user = create(:user)
    stub_payment_intent

    User::PremiumEntitlement::Grant.expects(:call).raises(ActiveRecord::RecordNotUnique)

    Stripe::FulfillPurchase.(user, "pi_123")
  end

  private
  def stub_payment_intent(status: "succeeded", refunded: false, disputed: false)
    charge = OpenStruct.new(id: "ch_123", receipt_url: "https://pay.stripe.com/receipts/abc", refunded:, disputed:)
    payment_intent = OpenStruct.new(
      id: "pi_123", status:, amount_received: 2399, currency: "gbp", customer: "cus_123", latest_charge: charge
    )
    ::Stripe::PaymentIntent.stubs(:retrieve).with(id: "pi_123", expand: ["latest_charge"]).returns(payment_intent)
  end
end
