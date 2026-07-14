class User
  class UpdateStreaksEnabled
    include Mandate

    initialize_with :user, :enabled

    def call
      user.data.update!(streaks_enabled: enabled?)
    end

    private
    # The column is NOT NULL, so writing the raw param straight through 500s
    # on a missing/null value (Sentry JIKI-API-R). Cast Rails-style and
    # reject anything that casts to nil so the controller can 422 instead.
    def enabled?
      value = ActiveModel::Type::Boolean.new.cast(enabled)
      raise InvalidBooleanError if value.nil?

      value
    end
  end
end
