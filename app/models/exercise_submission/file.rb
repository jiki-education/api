class ExerciseSubmission::File < ApplicationRecord
  belongs_to :exercise_submission
  has_one_attached :content, service: Rails.configuration.x.exercise_submission_storage_service

  validates :exercise_submission, presence: true
  validates :filename, presence: true
  validates :digest, presence: true
end
