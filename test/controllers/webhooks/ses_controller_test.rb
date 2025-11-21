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
    ::SES::Webhooks::Handle.expects(:call).with(body.to_json, 'SubscriptionConfirmation')

    post webhooks_ses_path,
      params: body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'x-amz-sns-message-type' => 'SubscriptionConfirmation'
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
    ::SES::Webhooks::Handle.expects(:call).with(body.to_json, 'Notification')

    post webhooks_ses_path,
      params: body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'x-amz-sns-message-type' => 'Notification'
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
    ::SES::Webhooks::Handle.expects(:call).with(body.to_json, 'Notification')

    post webhooks_ses_path,
      params: body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'x-amz-sns-message-type' => 'Notification'
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

    post webhooks_ses_path,
      params: body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'x-amz-sns-message-type' => 'Notification'
      }

    assert_response :success
  end

  test "handles unknown message type gracefully" do
    body = {
      'Type' => 'UnknownType'
    }

    post webhooks_ses_path,
      params: body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'x-amz-sns-message-type' => 'UnknownType'
      }

    assert_response :success
  end

  test "returns 200 on error to prevent SNS retries" do
    body = {
      'Type' => 'Notification',
      'Message' => 'invalid json'
    }

    post webhooks_ses_path,
      params: body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'x-amz-sns-message-type' => 'Notification'
      }

    # Should return 200 even on error to prevent SNS retries
    assert_response :success
  end
end
