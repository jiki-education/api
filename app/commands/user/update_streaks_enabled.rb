class User
  class UpdateStreaksEnabled
    include Mandate

    initialize_with :user, :enabled

    def call
      user.data.update!(streaks_enabled: enabled)
    end
  end
end
