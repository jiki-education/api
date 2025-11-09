class EmailTemplate::TranslateToAllLocales
  include Mandate

  queue_as :translations

  initialize_with :source_template

  def call
    validate!

    target_locales.each do |locale|
      EmailTemplate::TranslateToLocale.defer(source_template, locale)
    end

    Rails.logger.info "Queued #{target_locales.count} translation jobs for email template #{source_template.id}"

    target_locales
  end

  private
  def validate!
    raise ArgumentError, "Source template must be in English (en)" unless source_template.locale == "en"
  end

  memoize
  def target_locales = all_locales - ["en"]

  memoize
  def all_locales = (I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES).map(&:to_s).uniq
end
