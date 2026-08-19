# I18n Configuration
# Defines every locale the application knows about, and which of them are live.

module I18n
  # Every locale the application knows about, in canonical BCP-47 casing.
  #
  # Mirrors the front end's ALL_LOCALES (app/lib/locales.ts). The two must stay
  # in step: the front end offers a locale switcher over its list, and anything
  # missing here is rejected by the explicit_locale validation, so a locale
  # present there but absent here shows up in the UI and then 422s when picked.
  #
  # Promoting a locale is a one-line edit to PRODUCTION_LOCALES below - this
  # list never changes when a locale goes live.
  ALL_LOCALES = %w[
    ar bn ca de el en
    es-ES es-419
    fa fr hi hu id it ja ko nl pl
    pt-PT pt-BR
    ro ru sr sv sw tr uk ur vi
    zh-CN zh-TW
  ].freeze

  # The live set: locales that ship to production. The locale-parity guard test
  # hard-fails on any of these that drifts from en.
  PRODUCTION_LOCALES = %w[el en es-419 fr hu it uk].freeze

  # The draft set: everything not yet live. Translation generation targets every
  # locale (so content can be pre-generated before a locale is promoted), but
  # users can only select drafts outside production.
  WIP_LOCALES = (ALL_LOCALES - PRODUCTION_LOCALES).freeze

  # Locales users can actually select. Production ships the live set only;
  # other environments serve everything so translation work can be exercised
  # in dev/test.
  SUPPORTED_LOCALES = (Jiki.env.production? ? PRODUCTION_LOCALES : ALL_LOCALES).freeze
end

# Constrain the locales I18n knows about to the set users can select.
# rails-i18n and devise-i18n ship translations for ~100 locales; without this
# they would all land in I18n.available_locales (and, in production, bloat the
# loaded translation set). Nothing in the app keys off available_locales - our
# own I18n::ALL_LOCALES / SUPPORTED_LOCALES constants drive locale logic - so
# this only trims the gem-provided noise.
I18n.available_locales = I18n::SUPPORTED_LOCALES.map(&:to_sym)
