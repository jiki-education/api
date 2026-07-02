class User
  class UpdateLocale
    include Mandate

    initialize_with :user, :new_locale

    def call
      user.data.update!(explicit_locale: new_locale)
    end
  end
end
