class Lesson::Translation::TranslateToLocale
  include Mandate

  queue_as :translations

  initialize_with :lesson, :target_locale

  def call
    validate!

    # Call Gemini API for translation
    translated = Gemini::Translate.(translation_prompt, translation_schema, model: :flash)

    # Upsert pattern: delete existing, create new
    Lesson::Translation.find_for(lesson, target_locale)&.destroy

    target_translation = Lesson::Translation.create!(
      lesson:,
      locale: target_locale,
      title: translated[:title],
      description: translated[:description]
    )

    Rails.logger.info "Translated lesson #{lesson.slug} → #{target_locale}"

    target_translation
  rescue Gemini::RateLimitError => e
    # Let Solid Queue handle retry with backoff
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
        title: { type: "string" },
        description: { type: "string" }
      },
      required: %w[title description]
    }
  end

  memoize
  def translation_prompt
    <<~PROMPT
      You are a professional localization expert specializing in educational content translation.

      Task: Translate lesson content from English to #{locale_display_name} (#{target_locale}).

      Context:
      - Lesson: #{lesson.title} (#{lesson.slug})
      - Lesson Type: #{lesson.type}
      - Target Language: #{locale_display_name} (#{target_locale})

      Translation Rules:
      1. Maintain the original meaning, tone, and educational intent
      2. Use natural, native-sounding language for #{locale_display_name}
      3. Preserve any markdown formatting (**, *, lists, etc.) if present
      4. Maintain an encouraging, educational tone appropriate for coding learners
      5. Keep the description clear and concise
      6. Do not translate code examples, variable names, or technical terms that are universally English
      7. Consider the lesson type (#{lesson.type}) when choosing appropriate terminology

      Source Content to Translate:

      Title:
      #{lesson.title}

      Description:
      #{lesson.description}

      Required Output:
      Return ONLY a valid JSON object with these two fields (no additional text or markdown):
      {
        "title": "translated title",
        "description": "translated description"
      }
    PROMPT
  end
end
