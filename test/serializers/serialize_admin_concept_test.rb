require "test_helper"

class SerializeAdminConceptTest < ActiveSupport::TestCase
  test "serializes concept with all fields" do
    video_sources = [{ provider: "mux", id: "abc123" }]
    lesson = create(:lesson, :video, data: { sources: video_sources })
    concept = create(:concept,
      title: "Loops",
      slug: "loops",
      description: "Learn about loops",
      unlocked_by_lesson: lesson)

    result = SerializeAdminConcept.(concept)

    assert_equal concept.id, result[:id]
    assert_equal "Loops", result[:title]
    assert_equal "loops", result[:slug]
    assert_equal "Learn about loops", result[:description]
    assert_equal video_sources, result[:video_data]
  end
end
