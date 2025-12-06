class Lesson::Translation < ApplicationRecord
  belongs_to :lesson

  validates :locale, presence: true
  validates :title, presence: true
  validates :description, presence: true
  validates :locale, uniqueness: { scope: :lesson_id }
  validates :locale, exclusion: { in: ['en'], message: "English content belongs on Lesson model" }
  validates :locale, inclusion: {
    in: ->(_) { (I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES).map(&:to_s) - ['en'] },
    message: "is not a supported locale"
  }

  def self.find_for(lesson, locale)
    find_by(lesson:, locale:)
  end
end
