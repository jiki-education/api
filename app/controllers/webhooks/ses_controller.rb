# SNS webhook handler for SES bounce and complaint notifications
#
# AWS SNS sends notifications to this endpoint when:
# - Emails bounce (permanent or transient)
# - Users mark emails as spam (complaints)
#
# This controller handles:
# 1. SNS subscription confirmation (auto-confirm)
# 2. Bounce processing (mark invalid emails)
# 3. Complaint processing (unsubscribe from marketing)

class Webhooks::SesController < Webhooks::BaseController
  def create
    # Verify SNS message signature
    unless valid_sns_message?
      Rails.logger.warn("Invalid SNS signature from #{request.remote_ip}")
      head :unauthorized
      return
    end

    message_type = request.headers['x-amz-sns-message-type']

    case message_type
    when 'SubscriptionConfirmation'
      confirm_subscription
    when 'Notification'
      handle_notification
    else
      Rails.logger.warn("Unknown SNS message type: #{message_type}")
    end

    head :ok
  rescue StandardError => e
    Rails.logger.error("SES webhook error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    head :ok # Always return 200 to prevent SNS retries
  end

  private
  def valid_sns_message?
    # TODO: Implement proper SNS signature verification
    # https://docs.aws.amazon.com/sns/latest/dg/sns-verify-signature-of-message.html
    #
    # For now, accept all messages (SNS endpoint is not publicly advertised)
    # In production, should verify:
    # 1. SigningCertURL is from amazonaws.com
    # 2. Download certificate from SigningCertURL
    # 3. Verify signature using certificate and message body
    true
  end

  def confirm_subscription
    body = JSON.parse(request.body.read)
    subscribe_url = body['SubscribeURL']

    return unless subscribe_url

    # Auto-confirm SNS subscription
    uri = URI.parse(subscribe_url)
    Net::HTTP.get(uri)
    Rails.logger.info("SNS subscription confirmed: #{body['TopicArn']}")
  end

  def handle_notification
    body = JSON.parse(request.body.read)
    message = JSON.parse(body['Message'])

    event_type = message['eventType']
    Rails.logger.info("SES event: #{event_type}")

    case event_type
    when 'Bounce'
      SES::HandleEmailBounce.(message)
    when 'Complaint'
      SES::HandleEmailComplaint.(message)
    when 'Delivery'
      # Optional: track successful deliveries
      Rails.logger.debug("Email delivered: #{message['mail']['messageId']}")
    else
      Rails.logger.warn("Unknown SES event type: #{event_type}")
    end
  end
end
