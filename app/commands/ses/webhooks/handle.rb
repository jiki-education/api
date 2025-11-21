# Handles SNS webhook messages from AWS SES
#
# Processes different SNS message types:
# - SubscriptionConfirmation: Auto-confirm SNS topic subscription
# - Notification: Process SES events (bounces, complaints, deliveries)

class SES::Webhooks::Handle
  include Mandate

  initialize_with :request_body, :message_type

  def call
    case message_type
    when 'SubscriptionConfirmation'
      confirm_subscription!
    when 'Notification'
      handle_notification!
    end
  end

  private
  memoize
  def parsed_body = JSON.parse(request_body)

  def confirm_subscription!
    subscribe_url = parsed_body['SubscribeURL']
    return unless subscribe_url

    # Auto-confirm SNS subscription
    uri = URI.parse(subscribe_url)
    Net::HTTP.get(uri)
  end

  def handle_notification!
    case event_type
    when 'Bounce'
      SES::HandleEmailBounce.(message)
    when 'Complaint'
      SES::HandleEmailComplaint.(message)
    when 'Delivery'
      # Optional: track successful deliveries
      nil
    end
  end

  memoize
  def message = JSON.parse(parsed_body['Message'])

  memoize
  def event_type = message['eventType']
end
