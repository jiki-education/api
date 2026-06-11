require "test_helper"

class Exercism::Webhook::HandleEventTest < ActiveSupport::TestCase
  setup { stub_exercism_secrets! }
  teardown { unstub_exercism_secrets! }

  test "valid signature + activated dispatches to InsiderActivated" do
    payload = { event: "insider.activated", exercism_id: 1530 }.to_json
    signature = sign(payload)

    Exercism::Webhook::InsiderActivated.expects(:call).with(JSON.parse(payload))

    Exercism::Webhook::HandleEvent.(payload, signature)
  end

  test "valid signature + deactivated dispatches to InsiderDeactivated" do
    payload = { event: "insider.deactivated", exercism_id: 1530 }.to_json
    signature = sign(payload)

    Exercism::Webhook::InsiderDeactivated.expects(:call).with(JSON.parse(payload))

    Exercism::Webhook::HandleEvent.(payload, signature)
  end

  test "raises on invalid signature" do
    payload = { event: "insider.activated", exercism_id: 1530 }.to_json

    assert_raises(InvalidExercismWebhookSignatureError) do
      Exercism::Webhook::HandleEvent.(payload, "sha256=deadbeef")
    end
  end

  test "raises on missing signature" do
    payload = { event: "insider.activated", exercism_id: 1530 }.to_json

    assert_raises(InvalidExercismWebhookSignatureError) do
      Exercism::Webhook::HandleEvent.(payload, nil)
    end
  end

  test "raises on unknown event type" do
    payload = { event: "something.else", exercism_id: 1530 }.to_json
    signature = sign(payload)

    assert_raises(InvalidExercismWebhookEventError) do
      Exercism::Webhook::HandleEvent.(payload, signature)
    end
  end

  private
  def sign(payload)
    "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', Jiki.secrets.exercism_webhook_signing_secret, payload)}"
  end
end
