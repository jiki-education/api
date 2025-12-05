class Level < ApplicationRecord
  disable_sti!

  has_many :lessons, -> { order(:position) }, dependent: :destroy, inverse_of: :level
  has_many :user_levels, dependent: :destroy
  has_many :users, through: :user_levels
  has_many :translations, class_name: 'Level::Translation', dependent: :destroy

  validates :slug, presence: true, uniqueness: true
  validates :title, presence: true
  validates :description, presence: true
  validates :milestone_summary, presence: true
  validates :milestone_content, presence: true
  validates :position, presence: true, uniqueness: true

  before_validation :set_position, on: :create

  default_scope { order(:position) }

  # Get content for any locale (English from main model, others from translations with fallback)
  def content_for_locale(locale)
    model = locale.to_s == 'en' ? self : (translations.find_by(locale:) || self)

    {
      title: model.title,
      description: model.description,
      milestone_summary: model.milestone_summary,
      milestone_content: model.milestone_content
    }
  end

  # Get translation for a specific locale (returns nil for English since it's on main model)
  def translation_for(locale)
    return nil if locale.to_s == 'en'

    translations.find_by(locale:)
  end

  private
  def set_position
    return if position.present?

    self.position = (self.class.maximum(:position) || 0) + 1
  end
end
