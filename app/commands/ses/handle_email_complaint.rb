# Handles spam complaint notifications from SES via SNS
#
# When a user marks an email as spam, ISPs notify SES via feedback loop.
# We must immediately stop sending marketing emails to that address to
# protect sender reputation.
#
# Complaint rate must stay below 0.1% or AWS may suspend sending.

module SES
  class HandleEmailComplaint
    include Mandate

    initialize_with :event

    def call
      complaint = event['complaint']
      complained_recipients = complaint['complainedRecipients']
      complaint_feedback_type = complaint['complaintFeedbackType'] # abuse, fraud, etc

      Rails.logger.warn("Processing spam complaint (#{complaint_feedback_type}) for #{complained_recipients.count} recipients")

      # Batch load users to avoid N+1 queries
      emails = complained_recipients.map { |r| r['emailAddress'] }
      users_by_email = User.includes(:data).where(email: emails).index_by(&:email)

      complained_recipients.each do |recipient|
        email = recipient['emailAddress']
        user = users_by_email[email]
        handle_complaint(user, email, complaint_feedback_type)
      end
    end

    private
    def handle_complaint(user, email, feedback_type)
      Rails.logger.warn("Spam complaint: #{email} - #{feedback_type}")

      return unless user&.data

      # Immediately unsubscribe from marketing emails
      user.data.update!(
        marketing_emails_enabled: false,
        email_complaint_at: Time.current,
        email_complaint_type: feedback_type
      )

      Rails.logger.info("Unsubscribed #{email} from marketing emails")

      # Critical: DO NOT send marketing emails to this address again
      # Transactional emails (auth, payments) can still be sent
    end
  end
end
