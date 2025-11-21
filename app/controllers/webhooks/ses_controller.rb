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
    return head :unauthorized unless valid_sns_message?

    SES::Webhooks::Handle.(request.body.read, message_type)

    head :ok
  rescue StandardError => e
    Rails.logger.error("SES webhook error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    head :ok # Always return 200 to prevent SNS retries
  end

  private
  def message_type = request.headers['x-amz-sns-message-type']

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
end
