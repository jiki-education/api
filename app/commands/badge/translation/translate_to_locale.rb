class Badge::Translation::TranslateToLocale
  include Mandate

  queue_as :translations

  initialize_with :badge, :target_locale

  def call
    validate!

    # Call Gemini API for translation
    translated = Gemini::Translate.(translation_prompt, translation_schema, model: :flash)

    # Upsert pattern: delete existing, create new
    Badge::Translation.find_for(badge, target_locale)&.destroy

    target_translation = Badge::Translation.create!(
      badge:,
      locale: target_locale,
      name: translated[:name],
      description: translated[:description],
      fun_fact: translated[:fun_fact]
    )

    Rails.logger.info "Translated badge #{badge.slug} → #{target_locale}"

    target_translation
  rescue Gemini::RateLimitError => e
    # Let Sidekiq handle retry with backoff
    raise e
  end

  private
  def validate!
    raise ArgumentError, "Target locale cannot be English (en)" if target_locale == "en"
    raise ArgumentError, "Target locale not supported" unless supported_locales.include?(target_locale)
  end

  memoize
  def supported_locales
    (I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES).map(&:to_s)
  end

  memoize
  def locale_display_name
    I18n.t("locales.#{target_locale}", default: target_locale.upcase)
  end

  memoize
  def translation_schema
    {
      type: "object",
      properties: {
        name: { type: "string" },
        description: { type: "string" },
        fun_fact: { type: "string" }
      },
      required: %w[name description fun_fact]
    }
  end

  memoize
  def translation_prompt
    <<~PROMPT
      You are a professional localization expert specializing in educational content translation.

      Task: Translate badge content from English to #{locale_display_name} (#{target_locale}).

      Context:
      - Badge: #{badge.name} (#{badge.slug})
      - Target Language: #{locale_display_name} (#{target_locale})

      Translation Rules:
      1. Maintain the original meaning, tone, and celebratory intent
      2. Use natural, native-sounding language for #{locale_display_name}
      3. Maintain an encouraging, positive tone appropriate for achievement badges
      4. Keep the name concise (2-4 words typically)
      5. Keep the description clear and brief
      6. The fun_fact should be engaging and educational

      Source Content to Translate:

      Name:
      #{badge.name}

      Description:
      #{badge.description}

      Fun Fact:
      #{badge.fun_fact}

      Required Output:
      Return ONLY a valid JSON object with these three fields (no additional text or markdown):
      {
        "name": "translated name",
        "description": "translated description",
        "fun_fact": "translated fun fact"
      }
    PROMPT
  end
end
