# I18n Configuration
# Defines supported and work-in-progress locales for the application

module I18n
  # Locales that ship to production. The locale-parity guard test hard-fails
  # on any of these that drifts from en.
  PRODUCTION_LOCALES = %w[en hu].freeze

  # Locales that are being worked on but are not yet production-ready.
  # Translation generation targets these everywhere (so content can be
  # pre-generated before a locale is promoted), but users can only select
  # them outside production.
  #
  # Mirrors the front end's ALL_LOCALES (app/lib/locales.ts), in canonical
  # BCP-47 casing. The two must stay in step: the front end offers a locale
  # switcher over its list, and anything missing here is rejected by the
  # explicit_locale validation, so a locale present there but absent here
  # shows up in the UI and then 422s when picked.
  WIP_LOCALES = %w[
    ar bn ca de el
    es-ES es-419
    fa fr hi id it ja ko nl pl
    pt-PT pt-BR
    ro ru sr sv sw tr uk ur vi
    zh-CN zh-TW
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
