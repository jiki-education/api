# I18n Configuration
# Defines supported and work-in-progress locales for the application

module I18n
  # Locales that ship to production. Production is English-only for now; the
  # locale-parity guard test hard-fails on any of these that drifts from en.
  PRODUCTION_LOCALES = %w[en].freeze

  # Locales that are being worked on but are not yet production-ready.
  # Translation generation targets these everywhere (so content can be
  # pre-generated before a locale is promoted), but users can only select
  # them outside production.
  WIP_LOCALES = %w[
    hu
    es-ES es-419
    pt-PT pt-BR
  ].freeze

  # Locales users can actually select. Production ships PRODUCTION_LOCALES
  # only; other environments include the WIP set so translation work can
  # be exercised in dev/test.
  SUPPORTED_LOCALES = (
    Jiki.env.production? ? PRODUCTION_LOCALES : PRODUCTION_LOCALES + WIP_LOCALES
  ).freeze
end

# Constrain the locales I18n knows about to the set users can select.
# rails-i18n and devise-i18n ship translations for ~100 locales; without this
# they would all land in I18n.available_locales (and, in production, bloat the
# loaded translation set). Nothing in the app keys off available_locales - our
# own I18n::SUPPORTED_LOCALES / WIP_LOCALES constants drive locale logic - so
# this only trims the gem-provided noise.
I18n.available_locales = I18n::SUPPORTED_LOCALES.map(&:to_sym).uniq
