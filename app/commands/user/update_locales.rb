class User::UpdateLocales
  include Mandate

  initialize_with :user, :accept_language, force: false

  def call
    return if user.data.locales.present? && !force

    locales = User::ParseAcceptLanguage.(accept_language)
    return if locales.empty?

    user.data.update_column(:locales, locales)

    # Re-sync PostHog so the person's locale/locales reflect the new preferences.
    User::Identify.defer(user)
  end
end
