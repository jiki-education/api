class UserLevel < ApplicationRecord
  include Emailable

  belongs_to :user
  belongs_to :level
  belongs_to :course
  belongs_to :current_user_lesson, class_name: "UserLesson", optional: true
  has_many :user_courses_as_current,
    class_name: "UserCourse",
    foreign_key: :current_user_level_id,
    dependent: :nullify,
    inverse_of: :current_user_level

  validates :user_id, uniqueness: { scope: :level_id }

  # Always send emails for level completion (no specific preference key)
  def email_communication_preferences_key
    nil
  end

  # Check if an email template exists for this level completion
  def email_should_send?
    EmailTemplate.exists?(
      type: :level_completion,
      slug: level.slug,
      locale: user.locale
    )
  end
end
