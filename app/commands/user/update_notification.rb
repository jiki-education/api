class User
  class UpdateNotification
    include Mandate

    initialize_with :user, :slug, :value

    def call
      raise InvalidNotificationSlugError unless User::Data.valid_notification_slug?(slug)

      column = User::Data.notification_column_for(slug)
      user.data.update!(column => value)
    end

    class InvalidNotificationSlugError < StandardError; end
  end
end
