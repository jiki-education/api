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
    Rails.logger.info("Processing #{bounce_type} bounce for #{bounced_recipients.count} recipients")

    bounced_recipients.each do |recipient|
      next unless bounce_type == 'Permanent'

      email = recipient['emailAddress']
      diagnostic_code = recipient['diagnosticCode']
      user = users_by_email[email]

      handle_permanent_bounce!(user, email, diagnostic_code)
    end
  end

  private
  memoize
  def bounce = event['bounce']

  memoize
  def bounced_recipients = bounce['bouncedRecipients']

  memoize
  def bounce_type = bounce['bounceType']

  memoize
  def users_by_email
    emails = bounced_recipients.map { |r| r['emailAddress'] }
    User.includes(:data).where(email: emails).index_by(&:email)
  end

  def handle_permanent_bounce!(user, email, diagnostic_code)
    Rails.logger.warn("Hard bounce: #{email} - #{diagnostic_code}")

    return unless user&.data

    # Mark email as invalid to prevent future sending
    user.data.update!(
      email_valid: false,
      email_bounce_reason: diagnostic_code,
      email_bounced_at: Time.current
    )

    Rails.logger.info("Marked #{email} as invalid in database")
  end
end
