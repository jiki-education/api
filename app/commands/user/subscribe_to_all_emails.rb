class User
  class SubscribeToAllEmails
    include Mandate

    initialize_with :user

    def call
      user.data.update!(
        receive_newsletters: true,
        receive_event_emails: true,
        receive_milestone_emails: true,
        receive_activity_emails: true
      )
    end
  end
end
