# Handles email bounce notifications from SES via SNS
#
# Bounce types:
# - Permanent: Email address doesn't exist, mailbox full (terminal)
# - Transient: Temporary issue, may resolve (retry)
#
# For permanent bounces, we mark the email as invalid to prevent
# future sending and protect sender reputation.

class SES::HandleEmailBounce
  include Mandate

  initialize_with :event

  def call
    bounced_recipients.each do |recipient|
      next unless bounce_type == 'Permanent'

      handle_permanent_bounce!(
        recipient['emailAddress'],
        recipient['diagnosticCode']
      )
    end
  end

  private
  def handle_permanent_bounce!(email, diagnostic_code)
    user = users_by_email[email]
    return unless user&.data

    # Mark email as bounced to prevent future sending
    user.data.update!(
      email_bounce_reason: diagnostic_code,
      email_bounced_at: Time.current
    )
  end

  memoize
  def users_by_email
    emails = bounced_recipients.map { |r| r['emailAddress'] }
    User.includes(:data).where(email: emails).index_by(&:email)
  end

  memoize
  def bounce = event['bounce']

  memoize
  def bounced_recipients = bounce['bouncedRecipients']

  memoize
  def bounce_type = bounce['bounceType']
end
