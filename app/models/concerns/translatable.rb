module Translatable
  extend ActiveSupport::Concern

  included do
    # Define translatable_fields class method that must be implemented by including class
    class_attribute :translatable_fields
  end

  # Get content for any locale (English from main model, others from translations with fallback)
  def content_for_locale(locale)
    model = locale.to_s == 'en' ? self : (translations.find_by(locale:) || self)

    self.class.translatable_fields.index_with { |field| model.public_send(field) }
  end

  # Get translation for a specific locale (returns nil for English since it's on main model)
  def translation_for(locale)
    return nil if locale.to_s == 'en'

    translations.find_by(locale:)
  end
end
