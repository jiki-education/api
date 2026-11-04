require "test_helper"

class Stripe::Webhook::DisputeCreatedTest < ActiveSupport::TestCase
  test "revokes the disputed purchase" do
    Stripe::RevokePurchase.expects(:call).with("pi_123", "disputed")

    Stripe::Webhook::DisputeCreated.(OpenStruct.new(data: OpenStruct.new(object: OpenStruct.new(payment_intent: "pi_123"))))
  end

  test "ignores disputes without a payment intent" do
    Stripe::RevokePurchase.expects(:call).never

    Stripe::Webhook::DisputeCreated.(OpenStruct.new(data: OpenStruct.new(object: OpenStruct.new(payment_intent: nil))))
  end
end
