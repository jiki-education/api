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

class Webhooks::SESController < Webhooks::BaseController
  def create
    SES::Webhooks::Handle.(request)

    head :ok
  rescue InvalidSNSSignatureError
    head :unauthorized
  rescue StandardError
    head :ok # Always return 200 to prevent SNS retries
  end
end
