class Level::Translation::TranslateToAllLocales
  include Mandate

  queue_as :translations

  initialize_with :level

  def call
    target_locales.each do |locale|
      Level::Translation::TranslateToLocale.defer(level, locale)
    end

    target_locales
  end

  private
  memoize
  def target_locales = supported_locales - ["en"]

  memoize
  def supported_locales
    (I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES).map(&:to_s)
  end
end
