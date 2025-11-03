class ExerciseSubmission < ApplicationRecord
  belongs_to :context, polymorphic: true
  has_many :files, -> { order(:filename) },
    class_name: "ExerciseSubmission::File",
    dependent: :destroy,
    inverse_of: :exercise_submission

  validates :uuid, presence: true, uniqueness: true
  validates :context, presence: true

  delegate :user, to: :context

  def to_param = uuid
end
