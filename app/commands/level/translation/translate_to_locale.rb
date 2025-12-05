class Level::Translation::TranslateToLocale
  include Mandate

  queue_as :translations

  initialize_with :level, :target_locale

  def call
    validate!

    # Call Gemini API for translation
    translated = Gemini::TranslateMilestone.(translation_prompt, model: :flash)

    # Upsert pattern: delete existing, create new
    Level::Translation.find_for(level, target_locale)&.destroy

    target_translation = Level::Translation.create!(
      level:,
      locale: target_locale,
      title: translated[:title],
      description: translated[:description],
      milestone_summary: translated[:milestone_summary],
      milestone_content: translated[:milestone_content]
    )

    Rails.logger.info "Translated level #{level.slug} → #{target_locale}"

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
  def translation_prompt
    <<~PROMPT
      You are a professional localization expert specializing in educational content translation.

      Task: Translate level content from English to #{locale_display_name} (#{target_locale}).

      Context:
      - Level: #{level.title} (#{level.slug})
      - Target Language: #{locale_display_name} (#{target_locale})

      Translation Rules:
      1. Maintain the original meaning, tone, and motivational intent
      2. Keep the milestone_summary concise (2-3 sentences maximum)
      3. The milestone_content can be longer and more detailed
      4. Preserve any markdown formatting (**, *, lists, etc.)
      5. Use natural, native-sounding language for #{locale_display_name}
      6. Maintain an encouraging, educational tone appropriate for coding learners
      7. Do not translate code examples, variable names, or technical terms that are universally English

      Source Content to Translate:

      Title:
      #{level.title}

      Description:
      #{level.description}

      Milestone Summary (short, shown after completion):
      #{level.milestone_summary}

      Milestone Content (longer, shown in modal):
      #{level.milestone_content}

      Required Output:
      Return ONLY a valid JSON object with these four fields (no additional text or markdown):
      {
        "title": "translated title",
        "description": "translated description",
        "milestone_summary": "translated summary text",
        "milestone_content": "translated content text"
      }
    PROMPT
  end
end
