class SerializeEmailPreferences
  include Mandate

  initialize_with :user

  def call
    {
      email: user.email,
      newsletters: user.data.receive_newsletters,
      event_emails: user.data.receive_event_emails,
      milestone_emails: user.data.receive_milestone_emails,
      activity_emails: user.data.receive_activity_emails
    }
  end
end
