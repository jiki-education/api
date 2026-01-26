class Level < ApplicationRecord
  include Translatable

  disable_sti!

  belongs_to :course
  has_many :lessons, -> { order(:position) }, dependent: :destroy, inverse_of: :level
  has_many :user_levels, dependent: :destroy
  has_many :users, through: :user_levels
  has_many :translations, class_name: 'Level::Translation', dependent: :destroy

  self.translatable_fields = %i[title description milestone_summary milestone_content]

  validates :slug, presence: true, uniqueness: true
  validates :title, presence: true
  validates :description, presence: true
  validates :milestone_summary, presence: true
  validates :milestone_content, presence: true
  validates :position, presence: true, uniqueness: { scope: :course_id }

  before_validation :set_position, on: :create

  default_scope { order(:position) }

  private
  def set_position
    return if position.present?

    self.position = (course.levels.maximum(:position) || 0) + 1 if course
  end
end
