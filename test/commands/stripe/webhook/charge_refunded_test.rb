require "test_helper"

class Stripe::Webhook::ChargeRefundedTest < ActiveSupport::TestCase
  test "revokes the purchase on a full refund" do
    Stripe::RevokePurchase.expects(:call).with("pi_123", "refunded")

    Stripe::Webhook::ChargeRefunded.(event_for(refunded: true))
  end

  test "ignores partial refunds" do
    Stripe::RevokePurchase.expects(:call).never

    Stripe::Webhook::ChargeRefunded.(event_for(refunded: false))
  end

  test "ignores charges without a payment intent" do
    Stripe::RevokePurchase.expects(:call).never

    Stripe::Webhook::ChargeRefunded.(event_for(refunded: true, payment_intent: nil))
  end

  private
  def event_for(refunded:, payment_intent: "pi_123")
    OpenStruct.new(data: OpenStruct.new(object: OpenStruct.new(refunded:, payment_intent:)))
  end
end
