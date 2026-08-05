class Level < ApplicationRecord
  include Translatable

  disable_sti!

  belongs_to :course
  has_many :lessons, -> { order(:position) }, dependent: :destroy, inverse_of: :level
  has_many :user_levels, dependent: :destroy
  has_many :users, through: :user_levels
  has_many :translations, class_name: 'Level::Translation', dependent: :destroy

  # Email copy only - everything a screen renders is authored in the front-end
  # curriculum repo.
  self.translatable_fields = %i[milestone_email_subject milestone_email_content_markdown]

  # Dropped in a follow-up migration; ignored here so this code never selects
  # them and the drop is safe once this deploy has rolled out.
  self.ignored_columns += %w[title description milestone_summary milestone_content]

  validates :uuid, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  validates :position, presence: true, uniqueness: { scope: :course_id }

  before_validation :generate_uuid, on: :create
  before_validation :set_position, on: :create

  default_scope { order(:position) }

  private
  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def set_position
    return if position.present?
    return unless course

    self.position = (course.levels.maximum(:position) || 0) + 1
  end
end
