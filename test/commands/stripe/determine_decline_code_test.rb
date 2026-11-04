require "test_helper"

class Stripe::DetermineDeclineCodeTest < ActiveSupport::TestCase
  test "returns nil without a payment intent" do
    assert_nil Stripe::DetermineDeclineCode.(nil)
  end

  test "returns nil without a payment error" do
    assert_nil Stripe::DetermineDeclineCode.(OpenStruct.new(last_payment_error: nil))
  end

  test "prefers decline_code over code" do
    payment_intent = OpenStruct.new(last_payment_error: OpenStruct.new(decline_code: "insufficient_funds", code: "card_declined"))

    assert_equal "insufficient_funds", Stripe::DetermineDeclineCode.(payment_intent)
  end

  test "falls back to code" do
    payment_intent = OpenStruct.new(last_payment_error: OpenStruct.new(decline_code: nil, code: "expired_card"))

    assert_equal "expired_card", Stripe::DetermineDeclineCode.(payment_intent)
  end

  test "collapses sensitive codes to card_declined" do
    Stripe::DetermineDeclineCode::SENSITIVE_DECLINE_CODES.each do |code|
      payment_intent = OpenStruct.new(last_payment_error: OpenStruct.new(decline_code: code))

      assert_equal "card_declined", Stripe::DetermineDeclineCode.(payment_intent)
    end
  end
end
