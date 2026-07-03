class User::ParseAcceptLanguage
  include Mandate

  initialize_with :header

  # Headers are client-controlled, so cap how much we store.
  MAX_LOCALES = 10

  # A language tag like "en", "en-GB" or "zh-Hant-TW". Deliberately excludes
  # the "*" wildcard — it carries no preference information worth storing.
  TAG_REGEX = /\A[A-Za-z]{2,8}(-[A-Za-z0-9]{1,8})*\z/

  def call
    weighted_tags.
      sort_by.with_index { |(_, quality), index| [-quality, index] }.
      map(&:first).
      uniq.
      first(MAX_LOCALES)
  end

  private
  def weighted_tags
    header.to_s.split(",").filter_map do |entry|
      tag, *params = entry.split(";").map(&:strip)
      next unless tag&.match?(TAG_REGEX)

      quality = quality_from(params)
      next unless quality.positive?

      [normalize(tag), quality]
    end
  end

  def quality_from(params)
    params.each do |param|
      match = param.match(/\Aq\s*=\s*(\d(?:\.\d{1,3})?)\z/i)
      return match[1].to_f if match
    end
    1.0
  end

  # Canonical casing: language lowercase, region uppercase, script titlecase
  # (en-gb -> en-GB, ZH-hant -> zh-Hant).
  def normalize(tag)
    language, *subtags = tag.split("-")
    normalized = subtags.map do |subtag|
      case subtag.length
      when 2 then subtag.upcase
      when 4 then subtag.capitalize
      else subtag.downcase
      end
    end
    [language.downcase, *normalized].join("-")
  end
end
