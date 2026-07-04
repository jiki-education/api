# I18n Configuration
# Defines supported and work-in-progress locales for the application

module I18n
  # Locales that are fully supported and production-ready.
  # Production ships English only for now; other environments carry the
  # full set so translation work can continue in dev/test.
  SUPPORTED_LOCALES = (Jiki.env.production? ? %w[en] : %w[en hu]).freeze

  # Locales that are work-in-progress and not yet production-ready
  WIP_LOCALES = %w[fr].freeze
end
