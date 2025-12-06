class Level::Translation < ApplicationRecord
  disable_sti!

  self.table_name = 'level_translations'

  belongs_to :level

  validates :locale, presence: true
  validates :title, presence: true
  validates :description, presence: true
  validates :milestone_summary, presence: true
  validates :milestone_content, presence: true
  validates :locale, uniqueness: { scope: :level_id }
  validates :locale, exclusion: { in: ['en'], message: "English content belongs on Level model" }
  validates :locale, inclusion: {
    in: ->(_) { (I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES).map(&:to_s) - ['en'] },
    message: "is not a supported locale"
  }

  def self.find_for(level, locale)
    find_by(level:, locale:)
  end
end
