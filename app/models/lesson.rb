class Lesson < ApplicationRecord
  include Translatable

  disable_sti!

  belongs_to :level
  has_many :user_lessons, dependent: :destroy
  has_many :users, through: :user_lessons
  has_one :unlocked_concept, class_name: 'Concept', foreign_key: :unlocked_by_lesson_id, inverse_of: :unlocked_by_lesson
  has_one :unlocked_project, class_name: 'Project', foreign_key: :unlocked_by_lesson_id, inverse_of: :unlocked_by_lesson
  has_many :translations, class_name: 'Lesson::Translation', dependent: :destroy

  self.translatable_fields = %i[title description]

  serialize :data, coder: JSONWithIndifferentAccess

  def data = super || {}

  validates :slug, presence: true, uniqueness: true
  validates :title, presence: true
  validates :description, presence: true
  validates :type, presence: true
  validates :data, presence: true
  validates :position, presence: true, uniqueness: { scope: :level_id }
  validate :validate_data!

  before_validation :set_position, on: :create

  default_scope { order(:position) }

  def to_param = slug

  private
  def set_position
    return if position.present?

    self.position = (level.lessons.maximum(:position) || 0) + 1 if level
  end

  def validate_data!
    case type
    when 'exercise' then validate_exercise_data!
    when 'video' then validate_video_data!
    when 'choose_language' then validate_choose_language_data!
    end
  end

  def validate_exercise_data!
    return if data[:slug].present?

    errors.add(:data, 'must contain slug for exercise lessons')
  end

  def validate_video_data!
    return if data[:sources].present?

    errors.add(:data, 'must contain sources for video lessons')
  end

  def validate_choose_language_data!
    return if data[:sources].present?

    errors.add(:data, 'must contain sources for choose_language lessons')
  end
end
