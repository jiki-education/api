require "test_helper"

class SerializeAdminConceptTest < ActiveSupport::TestCase
  test "serializes concept with all fields" do
    video_sources = [{ provider: "mux", id: "abc123" }]
    lesson = create(:lesson, :video, data: { sources: video_sources })
    concept = create(:concept, slug: "loops", unlocked_by_lesson: lesson)

    result = SerializeAdminConcept.(concept)

    assert_equal({ id: concept.id, slug: "loops", video_data: video_sources }, result)
  end

  # Concept copy is authored in the front-end curriculum repo.
  test "does not include title or description" do
    result = SerializeAdminConcept.(create(:concept))

    refute result.key?(:title)
    refute result.key?(:description)
  end
end
