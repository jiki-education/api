class User::UpdateLocales
  include Mandate

  initialize_with :user, :accept_language

  def call
    locales = User::ParseAcceptLanguage.(accept_language)
    return if locales.empty?

    user.data.update_column(:locales, locales)
  end
end
