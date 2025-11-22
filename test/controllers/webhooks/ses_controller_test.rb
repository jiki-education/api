require "test_helper"

class Webhooks::SESControllerTest < ActionDispatch::IntegrationTest
  test "handles subscription confirmation" do
    subscribe_url = "https://sns.amazonaws.com/confirm-subscription?token=test"

    body = {
      'Type' => 'SubscriptionConfirmation',
      'TopicArn' => 'arn:aws:sns:us-east-1:123456789012:jiki-ses-bounces',
      'SubscribeURL' => subscribe_url
    }

    # Expect controller proxies to the command
    ::SES::Webhooks::Handle.expects(:call).with(instance_of(ActionDispatch::Request))

    post webhooks_ses_path,
      params: body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'x-amz-sns-message-type' => 'SubscriptionConfirmation',
        'x-amz-sns-signature' => 'fake-signature',
        'x-amz-sns-signing-cert-url' => 'https://sns.amazonaws.com/cert.pem',
        'x-amz-sns-signature-version' => '1'
      }

    assert_response :success
  end

  test "handles bounce notification" do
    bounce_message = {
      'eventType' => 'Bounce',
      'bounce' => {
        'bounceType' => 'Permanent',
        'bouncedRecipients' => [
          {
            'emailAddress' => 'invalid@example.com',
            'diagnosticCode' => 'smtp; 550 5.1.1 user unknown'
          }
        ]
      },
      'mail' => {
        'messageId' => 'test-message-id'
      }
    }

    body = {
      'Type' => 'Notification',
      'Message' => bounce_message.to_json
    }

    # Expect controller proxies to the command
    ::SES::Webhooks::Handle.expects(:call).with(instance_of(ActionDispatch::Request))

    post webhooks_ses_path,
      params: body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'x-amz-sns-message-type' => 'Notification',
        'x-amz-sns-signature' => 'fake-signature',
        'x-amz-sns-signing-cert-url' => 'https://sns.amazonaws.com/cert.pem',
        'x-amz-sns-signature-version' => '1'
      }

    assert_response :success
  end

  test "handles complaint notification" do
    complaint_message = {
      'eventType' => 'Complaint',
      'complaint' => {
        'complaintFeedbackType' => 'abuse',
        'complainedRecipients' => [
          {
            'emailAddress' => 'user@example.com'
          }
        ]
      },
      'mail' => {
        'messageId' => 'test-message-id'
      }
    }

    body = {
      'Type' => 'Notification',
      'Message' => complaint_message.to_json
    }

    # Expect controller proxies to the command
    ::SES::Webhooks::Handle.expects(:call).with(instance_of(ActionDispatch::Request))

    post webhooks_ses_path,
      params: body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'x-amz-sns-message-type' => 'Notification',
        'x-amz-sns-signature' => 'fake-signature',
        'x-amz-sns-signing-cert-url' => 'https://sns.amazonaws.com/cert.pem',
        'x-amz-sns-signature-version' => '1'
      }

    assert_response :success
  end

  test "handles delivery notification without error" do
    delivery_message = {
      'eventType' => 'Delivery',
      'mail' => {
        'messageId' => 'test-message-id'
      },
      'delivery' => {
        'timestamp' => '2025-11-19T10:00:00.000Z',
        'recipients' => ['user@example.com']
      }
    }

    body = {
      'Type' => 'Notification',
      'Message' => delivery_message.to_json
    }

    # Mock signature verification
    ::SES::Webhooks::VerifySignature.expects(:call).returns(true)

    post webhooks_ses_path,
      params: body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'x-amz-sns-message-type' => 'Notification',
        'x-amz-sns-signature' => 'fake-signature',
        'x-amz-sns-signing-cert-url' => 'https://sns.amazonaws.com/cert.pem',
        'x-amz-sns-signature-version' => '1'
      }

    assert_response :success
  end

  test "handles unknown message type gracefully" do
    body = {
      'Type' => 'UnknownType'
    }

    # Mock signature verification
    ::SES::Webhooks::VerifySignature.expects(:call).returns(true)

    post webhooks_ses_path,
      params: body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'x-amz-sns-message-type' => 'UnknownType',
        'x-amz-sns-signature' => 'fake-signature',
        'x-amz-sns-signing-cert-url' => 'https://sns.amazonaws.com/cert.pem',
        'x-amz-sns-signature-version' => '1'
      }

    assert_response :success
  end

  test "returns 200 on error to prevent SNS retries" do
    body = {
      'Type' => 'Notification',
      'Message' => 'invalid json'
    }

    # Mock signature verification to pass, but command will fail parsing
    ::SES::Webhooks::VerifySignature.expects(:call).returns(true)

    post webhooks_ses_path,
      params: body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'x-amz-sns-message-type' => 'Notification',
        'x-amz-sns-signature' => 'fake-signature',
        'x-amz-sns-signing-cert-url' => 'https://sns.amazonaws.com/cert.pem',
        'x-amz-sns-signature-version' => '1'
      }

    # Should return 200 even on error to prevent SNS retries
    assert_response :success
  end
end
