class Badge::Translation < ApplicationRecord
  belongs_to :badge

  validates :locale, presence: true
  validates :name, presence: true
  validates :description, presence: true
  validates :fun_fact, presence: true
  validates :locale, uniqueness: { scope: :badge_id }
  validates :locale, exclusion: { in: ['en'], message: "English content belongs on Badge model" }
  validates :locale, inclusion: {
    in: ->(_) { (I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES).map(&:to_s) - ['en'] },
    message: "is not a supported locale"
  }

  def self.find_for(badge, locale)
    find_by(badge:, locale:)
  end
end
