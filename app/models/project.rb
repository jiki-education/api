class Project < ApplicationRecord
  disable_sti!

  extend FriendlyId
  friendly_id :slug, use: [:history]

  # Associations
  belongs_to :unlocked_by_lesson, class_name: 'Lesson', optional: true
  has_many :user_projects, dependent: :destroy
  has_many :users, through: :user_projects

  # Validations
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :description, presence: true
  validates :exercise_slug, presence: true

  # Callbacks
  before_validation :generate_slug, on: :create

  # Use slug in URLs
  def to_param = slug

  private
  def generate_slug
    return if slug.present?
    return if title.blank?

    self.slug = title.parameterize
  end
end
