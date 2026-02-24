require "test_helper"

class LessonConceptTest < ActiveSupport::TestCase
  test "valid factory" do
    assert build(:lesson_concept).valid?
  end

  test "requires lesson" do
    lesson_concept = build(:lesson_concept, lesson: nil)
    refute lesson_concept.valid?
  end

  test "requires concept" do
    lesson_concept = build(:lesson_concept, concept: nil)
    refute lesson_concept.valid?
  end

  test "requires unique lesson-concept pair" do
    existing = create(:lesson_concept)
    duplicate = build(:lesson_concept, lesson: existing.lesson, concept: existing.concept)
    refute duplicate.valid?
  end
end
