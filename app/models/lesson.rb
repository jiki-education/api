class Lesson < ApplicationRecord
  include HasVideoData

  disable_sti!

  belongs_to :level
  has_many :user_lessons, dependent: :destroy
  has_many :users, through: :user_lessons
  has_many :unlocked_concepts, class_name: 'Concept', foreign_key: :unlocked_by_lesson_id, inverse_of: :unlocked_by_lesson
  has_one :unlocked_challenge, class_name: 'Challenge', foreign_key: :unlocked_by_lesson_id, inverse_of: :unlocked_by_lesson
  has_video_data :walkthrough_video_data

  serialize :data, coder: JSONWithIndifferentAccess

  def data = super || {}

  validates :uuid, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  validates :type, presence: true
  validates :position, presence: true, uniqueness: { scope: :level_id }
  validate :validate_data!

  before_validation :generate_uuid, on: :create
  before_validation :set_position, on: :create

  default_scope { order(:position) }

  def to_param = slug

  private
  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def set_position
    return if position.present?

    self.position = (level.lessons.maximum(:position) || 0) + 1 if level
  end

  # Exercise lessons carry no data - the lesson slug alone identifies the
  # front-end curriculum exercise at curriculum/src/exercises/<slug>/.
  def validate_data!
    case type
    when 'video' then validate_video_data!
    when 'choose_language' then validate_choose_language_data!
    end
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
