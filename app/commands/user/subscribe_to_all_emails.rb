class User
  class SubscribeToAllEmails
    include Mandate

    initialize_with :user

    def call
      updates = User::Data::NOTIFICATION_SLUGS.values.index_with { true }
      user.data.update!(updates)
    end
  end
end
