class User
  class UnsubscribeFromAllEmails
    include Mandate

    initialize_with :user

    def call
      updates = User::Data::NOTIFICATION_SLUGS.values.index_with { false }
      user.data.update!(updates)
    end
  end
end
