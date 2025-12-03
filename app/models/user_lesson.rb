class UserLesson < ApplicationRecord
  belongs_to :user
  belongs_to :lesson
  has_many :exercise_submissions, as: :context, dependent: :destroy
  has_many :user_levels_as_current,
    class_name: "UserLevel",
    foreign_key: :current_user_lesson_id,
    dependent: :nullify,
    inverse_of: :current_user_lesson

  validates :user_id, uniqueness: { scope: :lesson_id }

  def assistant_conversation
    AssistantConversation.find_by(
      user: user,
      context: lesson
    )
  end
end
