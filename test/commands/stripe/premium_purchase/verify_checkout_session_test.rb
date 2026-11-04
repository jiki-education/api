require "test_helper"

class Stripe::PremiumPurchase::VerifyCheckoutSessionTest < ActiveSupport::TestCase
  test "fulfils a paid session" do
    user = create(:user)
    stub_session(user)

    Stripe::PremiumPurchase::Fulfill.expects(:call).with(user, "pi_123")

    result = Stripe::PremiumPurchase::VerifyCheckoutSession.(user, "cs_123")

    assert_equal({ success: true, payment_state: "paid" }, result)
  end

  test "marks the purchase pending and reports processing when the payment is still clearing" do
    user = create(:user)
    stub_session(user, payment_status: "unpaid")

    Stripe::PremiumPurchase::Fulfill.expects(:call).never
    Stripe::PremiumPurchase::MarkPending.expects(:call).with(user, "pi_123")

    result = Stripe::PremiumPurchase::VerifyCheckoutSession.(user, "cs_123")

    assert_equal({ success: true, payment_state: "processing" }, result)
  end

  test "raises SecurityError when the session belongs to another user" do
    user = create(:user)
    stub_session(create(:user))

    assert_raises(SecurityError) { Stripe::PremiumPurchase::VerifyCheckoutSession.(user, "cs_123") }
  end

  test "raises SecurityError when the session has no user metadata" do
    user = create(:user)
    ::Stripe::Checkout::Session.stubs(:retrieve).with("cs_123").returns(OpenStruct.new(metadata: nil))

    assert_raises(SecurityError) { Stripe::PremiumPurchase::VerifyCheckoutSession.(user, "cs_123") }
  end

  test "raises ArgumentError for a subscription session" do
    user = create(:user)
    stub_session(user, mode: "subscription")

    assert_raises(ArgumentError) { Stripe::PremiumPurchase::VerifyCheckoutSession.(user, "cs_123") }
  end

  test "raises StripeCheckoutSessionIncompleteError with the decline code when not complete" do
    user = create(:user)
    stub_session(user, status: "open", payment_status: "unpaid")
    payment_intent = OpenStruct.new(last_payment_error: OpenStruct.new(decline_code: "insufficient_funds"))
    ::Stripe::Checkout::Session.stubs(:retrieve).with(id: "cs_123", expand: ["payment_intent"]).
      returns(OpenStruct.new(payment_intent:))

    error = assert_raises(StripeCheckoutSessionIncompleteError) do
      Stripe::PremiumPurchase::VerifyCheckoutSession.(user, "cs_123")
    end

    assert_equal "insufficient_funds", error.decline_code
    assert_equal "gbp", error.currency
    assert_nil error.interval
  end

  test "swallows Stripe errors while fetching the decline reason" do
    user = create(:user)
    stub_session(user, status: "expired", payment_status: "unpaid")
    ::Stripe::Checkout::Session.stubs(:retrieve).with(id: "cs_123", expand: ["payment_intent"]).
      raises(::Stripe::APIConnectionError.new("boom"))

    error = assert_raises(StripeCheckoutSessionIncompleteError) do
      Stripe::PremiumPurchase::VerifyCheckoutSession.(user, "cs_123")
    end

    assert_nil error.decline_code
  end

  private
  def stub_session(owner, mode: "payment", status: "complete", payment_status: "paid")
    session = OpenStruct.new(
      metadata: { "user_id" => owner.id.to_s },
      mode:,
      status:,
      payment_status:,
      payment_intent: "pi_123",
      currency: "gbp"
    )
    ::Stripe::Checkout::Session.stubs(:retrieve).with("cs_123").returns(session)
  end
end
