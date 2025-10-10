# Internationalization configuration
module I18n
  # Locales that are fully supported and visible to users
  SUPPORTED_LOCALES = %i[en hu].freeze

  # Locales that are work-in-progress (translations incomplete)
  WIP_LOCALES = [:fr].freeze
end

# Configure Rails I18n
Rails.application.config.i18n.available_locales = I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES
Rails.application.config.i18n.default_locale = :en
