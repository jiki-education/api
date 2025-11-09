class Lesson < ApplicationRecord
  disable_sti!

  belongs_to :level
  has_many :user_lessons, dependent: :destroy
  has_many :users, through: :user_lessons
  has_one :unlocked_concept, class_name: 'Concept', foreign_key: :unlocked_by_lesson_id, inverse_of: :unlocked_by_lesson
  has_one :unlocked_project, class_name: 'Project', foreign_key: :unlocked_by_lesson_id, inverse_of: :unlocked_by_lesson

  serialize :data, coder: JSONWithIndifferentAccess

  def data = super || {}

  validates :slug, presence: true, uniqueness: true
  validates :title, presence: true
  validates :description, presence: true
  validates :type, presence: true
  validates :data, presence: true
  validates :position, presence: true, uniqueness: { scope: :level_id }

  before_validation :set_position, on: :create

  default_scope { order(:position) }

  def to_param = slug

  private
  def set_position
    return if position.present?

    self.position = (level.lessons.maximum(:position) || 0) + 1 if level
  end
end
