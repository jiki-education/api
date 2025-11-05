require "test_helper"

class Webhooks::StripeControllerTest < ApplicationControllerTest
  test "POST create processes valid webhook" do
    payload = '{"type":"test.event"}'
    signature = "valid_signature"

    # The controller reads request.body.read which returns empty string in tests
    # unless we set it up properly
    Stripe::Webhook::HandleEvent.expects(:call).with do |_body, sig|
      sig == signature
    end

    post webhooks_stripe_path,
      params: payload,
      headers: { 'Stripe-Signature' => signature, 'Content-Type' => 'application/json' }

    assert_response :ok
  end

  test "POST create returns bad_request on signature verification failure" do
    payload = '{"type":"test.event"}'
    signature = "invalid_signature"

    Stripe::Webhook::HandleEvent.expects(:call).
      raises(Stripe::SignatureVerificationError.new("Invalid signature", signature))

    post webhooks_stripe_path,
      params: payload,
      headers: { 'Stripe-Signature' => signature }

    assert_response :bad_request
  end

  test "POST create returns ok even on processing errors" do
    payload = '{"type":"test.event"}'
    signature = "valid_signature"

    Stripe::Webhook::HandleEvent.expects(:call).
      raises(StandardError.new("Processing error"))

    post webhooks_stripe_path,
      params: payload,
      headers: { 'Stripe-Signature' => signature }

    # Should still return 200 to prevent Stripe retries
    assert_response :ok
  end
end
