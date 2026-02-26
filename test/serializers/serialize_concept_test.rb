require "test_helper"

class SerializeConceptTest < ActiveSupport::TestCase
  test "serializes concept with all fields" do
    video_sources = [{ host: "mux", id: "abc123" }]
    lesson = create(:lesson, :video, data: { sources: video_sources })
    concept = create(:concept,
      title: "Loops",
      slug: "loops",
      description: "Learn about loops",
      content_markdown: "# Loops",
      unlocked_by_lesson: lesson)

    result = SerializeConcept.(concept)

    assert_equal "Loops", result[:title]
    assert_equal "loops", result[:slug]
    assert_equal "Learn about loops", result[:description]
    assert_includes result[:content_html], "Loops"
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

  test "does not include content_markdown" do
    concept = create(:concept)

    result = SerializeConcept.(concept)

    refute result.key?(:content_markdown)
  end

  test "includes children_count" do
    parent = create(:concept)
    create(:concept, parent: parent)
    create(:concept, parent: parent)

    result = SerializeConcept.(parent.reload)

    assert_equal 2, result[:children_count]
  end

  test "includes ancestors array with title and slug only" do
    grandparent = create(:concept, title: "Grandparent", slug: "grandparent")
    parent = create(:concept, title: "Parent", slug: "parent", parent: grandparent)
    child = create(:concept, title: "Child", parent: parent)

    result = SerializeConcept.(child)

    assert_equal 2, result[:ancestors].length
    assert_equal({ title: "Grandparent", slug: "grandparent" }, result[:ancestors][0])
    assert_equal({ title: "Parent", slug: "parent" }, result[:ancestors][1])
  end

  test "ancestors does not include id" do
    parent = create(:concept)
    child = create(:concept, parent: parent)

    result = SerializeConcept.(child)

    refute result[:ancestors][0].key?(:id)
  end

  test "ancestors is empty for root concept" do
    concept = create(:concept)

    result = SerializeConcept.(concept)

    assert_empty result[:ancestors]
  end
end
