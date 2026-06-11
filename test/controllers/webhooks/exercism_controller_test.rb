require "test_helper"

class Webhooks::ExercismControllerTest < ApplicationControllerTest
  test "POST processes a valid webhook" do
    payload = '{"event":"insider.activated","exercism_id":1530}'
    signature = "sha256=abc"

    Exercism::Webhook::HandleEvent.expects(:call).with do |body, sig|
      body == payload && sig == signature
    end

    post webhooks_exercism_path,
      params: payload,
      headers: { "X-Exercism-Signature" => signature, "Content-Type" => "application/json" }

    assert_response :ok
  end

  test "POST returns 401 on signature failure" do
    payload = '{"event":"insider.activated","exercism_id":1530}'

    Exercism::Webhook::HandleEvent.expects(:call).
      raises(InvalidExercismWebhookSignatureError, "bad sig")

    post webhooks_exercism_path,
      params: payload,
      headers: { "X-Exercism-Signature" => "sha256=bad" }

    assert_response :unauthorized
  end

  test "POST returns 422 on malformed event" do
    payload = '{"event":"unknown"}'

    Exercism::Webhook::HandleEvent.expects(:call).
      raises(InvalidExercismWebhookEventError, "unknown event")

    post webhooks_exercism_path,
      params: payload,
      headers: { "X-Exercism-Signature" => "sha256=anything" }

    assert_response :unprocessable_entity
  end

  test "POST returns 200 on unexpected processing error to prevent retries" do
    Exercism::Webhook::HandleEvent.expects(:call).raises(StandardError, "boom")

    post webhooks_exercism_path,
      params: '{}',
      headers: { "X-Exercism-Signature" => "sha256=x" }

    assert_response :ok
  end

  test "POST returns 500 on transient DB errors to invite retries" do
    Exercism::Webhook::HandleEvent.expects(:call).raises(ActiveRecord::LockWaitTimeout, "lock")

    post webhooks_exercism_path,
      params: '{}',
      headers: { "X-Exercism-Signature" => "sha256=x" }

    assert_response :internal_server_error
  end
end
