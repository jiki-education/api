# Handles spam complaint notifications from SES via SNS
#
# When a user marks an email as spam, ISPs notify SES via feedback loop.
# We must immediately stop sending marketing emails to that address to
# protect sender reputation.
#
# Complaint rate must stay below 0.1% or AWS may suspend sending.

class SES::HandleEmailComplaint
  include Mandate

  initialize_with :event

  def call
    Rails.logger.warn("Processing spam complaint (#{complaint_feedback_type}) for #{complained_recipients.count} recipients")

    complained_recipients.each do |recipient|
      email = recipient['emailAddress']
      user = users_by_email[email]

      handle_complaint!(user, email)
    end
  end

  private
  memoize
  def complaint = event['complaint']

  memoize
  def complained_recipients = complaint['complainedRecipients']

  memoize
  def complaint_feedback_type = complaint['complaintFeedbackType']

  memoize
  def users_by_email
    emails = complained_recipients.map { |r| r['emailAddress'] }
    User.includes(:data).where(email: emails).index_by(&:email)
  end

  def handle_complaint!(user, email)
    Rails.logger.warn("Spam complaint: #{email} - #{complaint_feedback_type}")

    return unless user&.data

    # Immediately unsubscribe from marketing emails
    user.data.update!(
      marketing_emails_enabled: false,
      email_complaint_at: Time.current,
      email_complaint_type: complaint_feedback_type
    )

    Rails.logger.info("Unsubscribed #{email} from marketing emails")

    # Critical: DO NOT send marketing emails to this address again
    # Transactional emails (auth, payments) can still be sent
  end
end
