# Handles email bounce notifications from SES via SNS
#
# Bounce types:
# - Permanent: Email address doesn't exist, mailbox full (terminal)
# - Transient: Temporary issue, may resolve (retry)
#
# For permanent bounces, we mark the email as invalid to prevent
# future sending and protect sender reputation.

module SES
  class HandleEmailBounce
    include Mandate

    initialize_with :event

    def call
      bounce = event['bounce']
      bounced_recipients = bounce['bouncedRecipients']
      bounce_type = bounce['bounceType'] # Permanent or Transient

      Rails.logger.info("Processing #{bounce_type} bounce for #{bounced_recipients.count} recipients")

      # Batch load users to avoid N+1 queries
      emails = bounced_recipients.map { |r| r['emailAddress'] }
      users_by_email = User.includes(:data).where(email: emails).index_by(&:email)

      bounced_recipients.each do |recipient|
        email = recipient['emailAddress']
        diagnostic_code = recipient['diagnosticCode']
        user = users_by_email[email]

        if bounce_type == 'Permanent'
          handle_permanent_bounce(user, email, diagnostic_code)
        else
          handle_transient_bounce(email, diagnostic_code)
        end
      end
    end

    private
    def handle_permanent_bounce(user, email, diagnostic_code)
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

    def handle_transient_bounce(email, diagnostic_code)
      Rails.logger.info("Soft bounce: #{email} - #{diagnostic_code}")

      # Soft bounces may resolve (mailbox full, temporary server issue)
      # Log but don't disable email
      # Could track bounce count and disable after X soft bounces
    end
  end
end
