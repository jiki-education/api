# Maps Accept-Language tags to the canonical locale(s) they resolve to
# within a given locale set, preserving preference order. A tag whose exact
# or region-collapsed form isn't in the set is skipped entirely (falls
# through to the next tag) rather than producing a partial match. Shared by
# User::DetermineLocale (single, live-only) and User::DetermineLocales
# (all matches, live + draft).
class User::NormalizeLocaleTags
  include Mandate

  initialize_with :tags, :locale_set

  # Some languages ship more than one content variant, and which one a
  # browser gets depends on the region in its tag. This maps each such
  # language to:
  #   :bare     - the variant for a region-less tag (e.g. "pt" -> pt-BR)
  #   :regions  - explicit region -> variant overrides
  #   :fallback - the variant for any region not listed above
  # A tag whose language is absent here simply collapses to its base language.
  LANGUAGE_VARIANTS = {
    "pt" => { bare: "pt-BR", regions: { "BR" => "pt-BR" }.freeze, fallback: "pt-PT" },

    # Spanish ships two content variants: es-ES (Peninsular/Spain) and es-419
    # (neutral Latin American). Only the ES region maps to Peninsular; every
    # other region collapses to es-419. A region-less "es" defaults to es-419,
    # since Latin America is the far larger Spanish-speaking audience.
    "es" => { bare: "es-419", regions: { "ES" => "es-ES" }.freeze, fallback: "es-419" },

    # Chinese ships Simplified (zh-CN) and Traditional (zh-TW). The split is by
    # script, not country, so the Traditional-writing regions are listed
    # explicitly: Taiwan, Hong Kong and Macau. Everywhere else - and a
    # region-less "zh" - gets Simplified, which is the far larger audience.
    "zh" => {
      bare: "zh-CN",
      regions: { "TW" => "zh-TW", "HK" => "zh-TW", "MO" => "zh-TW" }.freeze,
      fallback: "zh-CN"
    }
  }.freeze

  def call
    parsed_tags.filter_map do |language, region, canonical|
      next canonical if supported?(canonical)

      target = collapse(language, region)
      target if supported?(target)
    end.uniq
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

  def supported?(locale) = locale_set.include?(locale)
end
