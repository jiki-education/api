class EmailTemplate < ApplicationRecord
  disable_sti!

  enum :type, { level_completion: 0 }

  validates :type, presence: true
  validates :locale, presence: true
  validates :subject, presence: true
  validates :body_mjml, presence: true
  validates :body_text, presence: true
  validates :type, uniqueness: { scope: %i[slug locale] }

  # Generic finder for any template type, slug, and locale
  # @param type [Symbol] The type of template (e.g., :level_completion)
  # @param slug [String] The template slug (e.g., level slug)
  # @param locale [String] The locale (e.g., "en", "hu")
  # @return [EmailTemplate, nil] The template if found, nil otherwise
  def self.find_for(type, slug, locale)
    find_by(type:, slug:, locale:)
  end

  # Scope to find level completion templates
  scope :for_level_completion, lambda { |level_slug, locale|
    where(type: :level_completion, slug: level_slug, locale:)
  }

  # Find a template for level completion, returning nil if not found
  def self.find_for_level_completion(level_slug, locale)
    find_for(:level_completion, level_slug, locale)
  end
end
