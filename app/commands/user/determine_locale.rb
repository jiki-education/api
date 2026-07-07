class User::DetermineLocale
  include Mandate

  initialize_with :tags

  # Some languages ship more than one content variant, and which one a browser
  # gets depends on the region in its tag. This maps each such language to:
  #   :bare     - the variant for a region-less tag (e.g. "pt" -> pt-BR)
  #   :regions  - explicit region -> variant overrides
  #   :fallback - the variant for any region not listed above
  # A tag whose language is absent here simply collapses to its base language.
  LANGUAGE_VARIANTS = {
    "pt" => { bare: "pt-BR", regions: { "BR" => "pt-BR" }.freeze, fallback: "pt-PT" },
    "es" => { bare: "es", regions: { "ES" => "es" }.freeze, fallback: "es-419" }
  }.freeze

  # Returns exactly one member of I18n::SUPPORTED_LOCALES, or nil when no
  # preference maps to a live locale (the caller then applies the default).
  #
  # Preference order is absolute: each tag is fully resolved (an exact live
  # match, else its region-collapsed content variant if that's live) before
  # moving on. A later exact match therefore never leapfrogs an earlier tag
  # that already collapses to something live. A tag whose variant isn't live
  # simply falls through to the next preference.
  def call
    parsed_tags.each do |language, region, canonical|
      return canonical if supported?(canonical)

      target = collapse(language, region)
      return target if supported?(target)
    end
    nil
  end

  private
  def collapse(language, region)
    variant = LANGUAGE_VARIANTS[language]
    return language unless variant

    return variant[:bare] if region.nil?

    variant[:regions].fetch(region, variant[:fallback])
  end

  memoize
  def parsed_tags = Array(tags).filter_map { |tag| parse(tag) }

  # Splits a tag into [language, region, canonical], normalising case since
  # Accept-Language isn't case-stable (language lowercased, region upcased so
  # "pt-br" and "419" both canonicalise correctly). Returns nil for a blank or
  # language-less tag.
  def parse(tag)
    parts = tag.to_s.split("-")
    language = parts.first.to_s.downcase
    return if language.blank?

    region = parts.drop(1).find { |part| part.match?(/\A([A-Za-z]{2}|\d{3})\z/) }&.upcase
    canonical = [language, region].compact.join("-")
    [language, region, canonical]
  end

  def supported?(locale) = I18n::SUPPORTED_LOCALES.include?(locale)
end
