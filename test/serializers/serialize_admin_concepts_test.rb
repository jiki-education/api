require "test_helper"

class SerializeAdminConceptsTest < ActiveSupport::TestCase
  test "serializes collection with all fields" do
    video_sources = [{ provider: "mux", id: "abc123" }]
    lesson = create(:lesson, :video, data: { sources: video_sources })
    concept = create(:concept, slug: "loops", unlocked_by_lesson: lesson)

    result = SerializeAdminConcepts.([concept])

    assert_equal [{ id: concept.id, slug: "loops", video_data: video_sources }], result
  end
end
