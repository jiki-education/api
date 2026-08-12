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
  def target_locales = I18n::ALL_LOCALES - ["en"]
end
