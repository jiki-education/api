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
    complained_recipients.each do |recipient|
      handle_complaint!(recipient['emailAddress'])
    end
  end

  private
  def handle_complaint!(email)
    user = users_by_email[email]
    return unless user&.data

    # Record spam complaint - email_wants_emails? will return false
    user.data.update!(
      email_complaint_at: Time.current,
      email_complaint_type: complaint_feedback_type
    )

    # Critical: DO NOT send marketing emails to this address again
    # Transactional emails (auth, payments) can still be sent
  end

  memoize
  def users_by_email
    emails = complained_recipients.map { |r| r['emailAddress'] }
    User.includes(:data).where(email: emails).index_by(&:email)
  end

  memoize
  def complaint = event['complaint']

  memoize
  def complained_recipients = complaint['complainedRecipients']

  memoize
  def complaint_feedback_type = complaint['complaintFeedbackType']
end
