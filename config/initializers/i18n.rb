# I18n Configuration
# Defines supported and work-in-progress locales for the application

module I18n
  # Locales that ship to production. Production is English-only for now; the
  # locale-parity guard test hard-fails on any of these that drifts from en.
  PRODUCTION_LOCALES = %w[en].freeze

  # Locales that are fully supported and production-ready.
  # Production ships PRODUCTION_LOCALES only; other environments carry the
  # full set so translation work can continue in dev/test.
  SUPPORTED_LOCALES = (
    Jiki.env.production? ? PRODUCTION_LOCALES : PRODUCTION_LOCALES + %w[
      hu
      es-ES es-419
      pt-PT pt-BR
    ]
  ).freeze

  # Locales that are work-in-progress and not yet production-ready
  WIP_LOCALES = %w[fr].freeze
end

# Constrain the locales I18n knows about to the set the app actually uses.
# rails-i18n and devise-i18n ship translations for ~100 locales; without this
# they would all land in I18n.available_locales (and, in production, bloat the
# loaded translation set). Nothing in the app keys off available_locales - our
# own I18n::SUPPORTED_LOCALES / WIP_LOCALES constants drive locale logic - so
# this only trims the gem-provided noise while keeping every locale we support
# valid to set.
I18n.available_locales = (I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES).map(&:to_sym).uniq
