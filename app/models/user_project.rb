class UserProject < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :project
  has_many :exercise_submissions, as: :context, dependent: :destroy

  # Validations
  validates :project_id, uniqueness: { scope: :user_id }

  # State helper methods
  def started? = started_at.present?
  def completed? = completed_at.present?

  def assistant_conversation
    AssistantConversation.find_by(
      user: user,
      context: project
    )
  end
end
