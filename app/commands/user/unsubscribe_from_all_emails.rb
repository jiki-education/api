class User
  class UnsubscribeFromAllEmails
    include Mandate

    initialize_with :user

    def call
      user.data.update!(
        receive_newsletters: false,
        receive_event_emails: false,
        receive_milestone_emails: false,
        receive_activity_emails: false
      )
    end
  end
end
