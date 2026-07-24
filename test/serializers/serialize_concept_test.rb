require "test_helper"

class SerializeConceptTest < ActiveSupport::TestCase
  test "serializes concept with all fields" do
    video_sources = [{ provider: "mux", id: "abc123" }]
    lesson = create(:lesson, :video, data: { sources: video_sources })
    concept = create(:concept,
      title: "Loops",
      slug: "loops",
      description: "Learn about loops",
      unlocked_by_lesson: lesson)

    result = SerializeConcept.(concept)

    assert_equal "Loops", result[:title]
    assert_equal "loops", result[:slug]
    assert_equal "Learn about loops", result[:description]
    assert_equal video_sources, result[:video_data]
  end

  test "video_data passes through duration and upload date when present" do
    video_sources = [{ provider: "mux", id: "abc123", durationSeconds: 372, uploadDate: "2026-05-15" }]
    lesson = create(:lesson, :video, data: { sources: video_sources })
    concept = create(:concept, unlocked_by_lesson: lesson)

    result = SerializeConcept.(concept)

    assert_equal video_sources, result[:video_data]
  end

  test "video_data is nil when no unlocked_by_lesson" do
    concept = create(:concept)

    result = SerializeConcept.(concept)

    assert_nil result[:video_data]
  end

  test "does not include id" do
    concept = create(:concept)

    result = SerializeConcept.(concept)

    refute result.key?(:id)
  end
end
