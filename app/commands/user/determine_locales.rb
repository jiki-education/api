class User::DetermineLocales
  include Mandate

  initialize_with :tags

  # Returns every distinct locale the user's Accept-Language preferences
  # resolve to, live or draft (I18n::ALL_LOCALES), in preference order. Unlike User::DetermineLocale this isn't gated on
  # production-live status - the FE decides which of these to surface.
  def call = User::NormalizeLocaleTags.(tags, I18n::ALL_LOCALES)
end
