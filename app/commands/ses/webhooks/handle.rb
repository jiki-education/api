# Handles SNS webhook messages from AWS SES
#
# Processes different SNS message types:
# - SubscriptionConfirmation: Auto-confirm SNS topic subscription
# - Notification: Process SES events (bounces, complaints, deliveries)

class SES::Webhooks::Handle
  include Mandate

  initialize_with :request

  def call
    verify_signature!

    case message_type
    when 'SubscriptionConfirmation'
      confirm_subscription!
    when 'Notification'
      handle_notification!
    end
  end

  private
  def verify_signature!
    verifier = Aws::SNS::MessageVerifier.new
    raise InvalidSNSSignatureError unless verifier.authentic?(request_body)
  end

  def confirm_subscription!
    subscribe_url = parsed_body['SubscribeURL']
    return unless subscribe_url

    # Auto-confirm SNS subscription
    HTTParty.get(subscribe_url, timeout: 10)
  end

  def handle_notification!
    case event_type
    when 'Bounce'
      SES::HandleEmailBounce.(message)
    when 'Complaint'
      SES::HandleEmailComplaint.(message)
    when 'Delivery'
      # Delivery notifications are disabled at the SNS level (terraform/aws/ses.tf)
      # Only bounces and complaints are sent to this webhook to minimize volume
      # Delivery metrics are sent to CloudWatch instead
      nil
    end
  end

  memoize
  def message_type = request.headers['x-amz-sns-message-type']

  memoize
  def request_body = request.body.read

  memoize
  def parsed_body = JSON.parse(request_body)

  memoize
  def message = JSON.parse(parsed_body['Message'])

  memoize
  def event_type = message['eventType']
end
