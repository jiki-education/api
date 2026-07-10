class UserChallenge < ApplicationRecord
  # The database table hasn't been renamed from the old "user_projects" naming yet.
  self.table_name = "user_projects"

  # Polymorphic rows (exercise_submissions.context_type) still store
  # "UserProject". Keep writing that name until the data is migrated.
  # See also the UserProject constant alias.
  def self.polymorphic_name = "UserProject"

  # Associations
  belongs_to :user
  belongs_to :challenge, foreign_key: :project_id, inverse_of: :user_challenges

  has_many :exercise_submissions, as: :context, dependent: :destroy

  # Validations
  # NB: project_id is the not-yet-renamed foreign key column for challenge.
  validates :project_id, uniqueness: { scope: :user_id }

  # State helper methods
  def started? = started_at.present?
  def completed? = completed_at.present?

  def assistant_conversation
    AssistantConversation.find_by(
      user: user,
      context: challenge
    )
  end
end
