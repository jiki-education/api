class LessonConcept < ApplicationRecord
  belongs_to :lesson
  belongs_to :concept

  validates :lesson_id, uniqueness: { scope: :concept_id }
end
