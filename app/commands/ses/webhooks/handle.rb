# Handles SNS webhook messages from AWS SES
#
# Processes different SNS message types:
# - SubscriptionConfirmation: Auto-confirm SNS topic subscription
# - Notification: Process SES events (bounces, complaints, deliveries)

module SES
  module Webhooks
    class Handle
      include Mandate

      initialize_with :request_body, :message_type

      def call
        case message_type
        when 'SubscriptionConfirmation'
          confirm_subscription!
        when 'Notification'
          handle_notification!
        else
          Rails.logger.warn("Unknown SNS message type: #{message_type}")
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
        Rails.logger.info("SNS subscription confirmed: #{parsed_body['TopicArn']}")
      end

      def handle_notification!
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

      memoize
      def message = JSON.parse(parsed_body['Message'])

      memoize
      def event_type = message['eventType']
    end
  end
end
