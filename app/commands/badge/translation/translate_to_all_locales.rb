class Badge::Translation::TranslateToAllLocales
  include Mandate

  queue_as :translations

  initialize_with :badge

  def call
    target_locales.each do |locale|
      Badge::Translation::TranslateToLocale.defer(badge, locale)
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
