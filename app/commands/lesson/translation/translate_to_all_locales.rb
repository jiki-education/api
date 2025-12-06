class Lesson::Translation::TranslateToAllLocales
  include Mandate

  queue_as :translations

  initialize_with :lesson

  def call
    target_locales.each do |locale|
      Lesson::Translation::TranslateToLocale.defer(lesson, locale)
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
