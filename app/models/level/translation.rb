class Level::Translation < ApplicationRecord
  belongs_to :level

  # Dropped in a follow-up migration; ignored here so this code never selects
  # them and the drop is safe once this deploy has rolled out.
  self.ignored_columns += %w[title description milestone_summary milestone_content]

  validates :locale, presence: true
  validates :milestone_email_subject, presence: true
  validates :milestone_email_content_markdown, presence: true
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
