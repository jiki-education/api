class Course < ApplicationRecord
  disable_sti!

  has_many :levels, -> { order(:position) }, dependent: :destroy, inverse_of: :course
  has_many :user_courses, dependent: :destroy
  has_many :users, through: :user_courses

  validates :slug, presence: true, uniqueness: true
  validates :title, presence: true
  validates :description, presence: true
  validates :position, presence: true, uniqueness: true

  before_validation :set_position, on: :create

  default_scope { order(:position) }

  def to_param = slug

  private
  def set_position
    return if position.present?

    self.position = (self.class.maximum(:position) || 0) + 1
  end
end
