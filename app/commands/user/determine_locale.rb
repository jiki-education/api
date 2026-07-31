class User::DetermineLocale
  include Mandate

  initialize_with :tags

  # Returns exactly one member of I18n::SUPPORTED_LOCALES, or nil when no
  # preference maps to a live locale (the caller then applies the default).
  #
  # Preference order is absolute: each tag is fully resolved (an exact live
  # match, else its region-collapsed content variant if that's live) before
  # moving on. A later exact match therefore never leapfrogs an earlier tag
  # that already collapses to something live. A tag whose variant isn't live
  # simply falls through to the next preference.
  def call = User::NormalizeLocaleTags.(tags, I18n::SUPPORTED_LOCALES).first
end
