class UserCourse < ApplicationRecord
  SUPPORTED_LANGUAGES = %w[javascript python].freeze

  belongs_to :user
  belongs_to :course
  belongs_to :current_user_level, class_name: "UserLevel", optional: true

  validates :user_id, uniqueness: { scope: :course_id }
  validates :language, inclusion: { in: SUPPORTED_LANGUAGES }, allow_nil: true

  def language_chosen?
    language.present?
  end

  def completed?
    completed_at.present?
  end
end
