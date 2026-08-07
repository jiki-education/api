class Level::Translation::TranslateToLocale
  include Mandate

  queue_as :translations

  initialize_with :level, :target_locale

  def call
    validate!

    # Call Gemini API for translation
    translated = Gemini::Translate.(translation_prompt, translation_schema, model: :flash)

    # Upsert pattern: delete existing, create new
    Level::Translation.find_for(level, target_locale)&.destroy

    target_translation = Level::Translation.create!(
      level:,
      locale: target_locale,
      milestone_email_subject: translated[:milestone_email_subject],
      milestone_email_content_markdown: translated[:milestone_email_content_markdown]
    )

    Rails.logger.info "Translated level #{level.slug} → #{target_locale}"

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
    (I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES).map(&:to_s).uniq
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
        milestone_email_subject: { type: "string" },
        milestone_email_content_markdown: { type: "string" }
      },
      required: %w[milestone_email_subject milestone_email_content_markdown]
    }
  end

  memoize
  def translation_prompt
    <<~PROMPT
      You are a professional localization expert specializing in educational content translation.

      Task: Translate level content from English to #{locale_display_name} (#{target_locale}).

      Context:
      - Level: #{level.slug}
      - Target Language: #{locale_display_name} (#{target_locale})

      Translation Rules:
      1. Maintain the original meaning, tone, and motivational intent
      2. Preserve any markdown formatting (**, *, lists, etc.)
      3. Use natural, native-sounding language for #{locale_display_name}
      4. Maintain an encouraging, educational tone appropriate for coding learners
      5. Do not translate code examples, variable names, or technical terms that are universally English
      6. This copy names the level it congratulates the learner on. Inflect that
         name naturally for #{locale_display_name} rather than transliterating it -
         nothing interpolates it, so the grammar is yours to get right.

      Source Content to Translate:

      Milestone Email Subject:
      #{level.milestone_email_subject}

      Milestone Email Content (markdown):
      #{level.milestone_email_content_markdown}

      Required Output:
      Return ONLY a valid JSON object with these two fields (no additional text or markdown):
      {
        "milestone_email_subject": "translated email subject",
        "milestone_email_content_markdown": "translated email content"
      }
    PROMPT
  end
end
