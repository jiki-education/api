class Concept < ApplicationRecord
  disable_sti!

  extend FriendlyId
  friendly_id :slug, use: [:history]

  belongs_to :unlocked_by_lesson, class_name: 'Lesson', optional: true

  # Dropped in a follow-up migration; ignored here so this code never selects
  # them and the drop is safe once this deploy has rolled out.
  self.ignored_columns += %w[title description]

  validates :uuid, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_uuid, on: :create

  def to_param = slug

  private
  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
