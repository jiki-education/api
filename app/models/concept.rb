class Concept < ApplicationRecord
  disable_sti!

  extend FriendlyId
  friendly_id :slug, use: [:history]

  belongs_to :unlocked_by_lesson, class_name: 'Lesson', optional: true

  validates :uuid, presence: true, uniqueness: true
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :description, presence: true

  before_validation :generate_uuid, on: :create
  before_validation :generate_slug, on: :create

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
