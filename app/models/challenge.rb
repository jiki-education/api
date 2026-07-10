class Challenge < ApplicationRecord
  disable_sti!

  extend FriendlyId
  friendly_id :slug, use: [:history]

  # Associations
  belongs_to :unlocked_by_lesson, class_name: 'Lesson', optional: true
  has_many :user_challenges, dependent: :destroy
  has_many :users, through: :user_challenges

  # Validations
  validates :uuid, presence: true, uniqueness: true
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :description, presence: true
  validates :exercise_slug, presence: true

  # Callbacks
  before_validation :generate_uuid, on: :create
  before_validation :generate_slug, on: :create

  # Use slug in URLs
  def to_param = slug

  private
  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def generate_slug
    return if slug.present?
    return if title.blank?

    self.slug = title.parameterize
  end
end
