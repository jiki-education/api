require "test_helper"

class Exercism::Webhook::HandleEventTest < ActiveSupport::TestCase
  setup { stub_exercism_secrets! }
  teardown { unstub_exercism_secrets! }

  test "defers a ResyncUser for the user identified by exercism_id" do
    user = create(:user, exercism_id: "1530")
    payload = { event: "insider.activated", exercism_id: 1530 }.to_json

    User::Exercism::ResyncUser.expects(:defer).with(user)

    Exercism::Webhook::HandleEvent.(payload, sign(payload))
  end

  test "ignores event type — any verified payload triggers a resync" do
    user = create(:user, exercism_id: "1530")
    payload = { event: "literally.anything", exercism_id: 1530 }.to_json

    User::Exercism::ResyncUser.expects(:defer).with(user)

    Exercism::Webhook::HandleEvent.(payload, sign(payload))
  end

  test "no-ops for unknown exercism_id" do
    payload = { event: "insider.activated", exercism_id: 9999 }.to_json

    User::Exercism::ResyncUser.expects(:defer).never

    Exercism::Webhook::HandleEvent.(payload, sign(payload))
  end

  test "no-ops when exercism_id is missing" do
    payload = { event: "insider.activated" }.to_json

    User::Exercism::ResyncUser.expects(:defer).never

    Exercism::Webhook::HandleEvent.(payload, sign(payload))
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

  private
  def sign(payload)
    "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', Jiki.secrets.exercism_webhook_signing_secret, payload)}"
  end
end
