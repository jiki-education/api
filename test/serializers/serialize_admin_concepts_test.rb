require "test_helper"

class SerializeAdminConceptsTest < ActiveSupport::TestCase
  test "serializes collection with all fields" do
    video_sources = [{ provider: "mux", id: "abc123" }]
    lesson = create(:lesson, :video, data: { sources: video_sources })
    concept = create(:concept,
      title: "Loops",
      slug: "loops",
      description: "Learn about loops",
      unlocked_by_lesson: lesson)

    result = SerializeAdminConcepts.([concept])

    assert_equal 1, result.length
    assert_equal concept.id, result[0][:id]
    assert_equal "Loops", result[0][:title]
    assert_equal "loops", result[0][:slug]
    assert_equal "Learn about loops", result[0][:description]
    assert_equal video_sources, result[0][:video_data]
  end

  test "includes children_count" do
    parent = create(:concept)
    create(:concept, parent: parent)
    create(:concept, parent: parent)

    result = SerializeAdminConcepts.([parent.reload])

    assert_equal 2, result[0][:children_count]
  end

  test "does not include ancestors in collection" do
    parent = create(:concept)
    child = create(:concept, parent: parent)

    result = SerializeAdminConcepts.([child])

    refute result[0].key?(:ancestors)
  end
end
