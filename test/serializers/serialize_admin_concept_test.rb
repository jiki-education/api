require "test_helper"

class SerializeAdminConceptTest < ActiveSupport::TestCase
  test "serializes concept with all fields" do
    lesson = create(:lesson, :exercise,
      walkthrough_video_data: [{ provider: "youtube", id: "abc123" }, { provider: "mux", id: "def456" }])
    concept = create(:concept,
      title: "Loops",
      slug: "loops",
      description: "Learn about loops",
      content_markdown: "# Loops",
      unlocked_by_lesson: lesson)

    result = SerializeAdminConcept.(concept)

    assert_equal concept.id, result[:id]
    assert_equal "Loops", result[:title]
    assert_equal "loops", result[:slug]
    assert_equal "Learn about loops", result[:description]
    assert_equal "# Loops", result[:content_markdown]
    expected_video_data = [{ provider: "youtube", id: "abc123" }, { provider: "mux", id: "def456" }]
    assert_equal expected_video_data, result[:video_data]
  end

  test "includes children_count" do
    parent = create(:concept)
    create(:concept, parent: parent)
    create(:concept, parent: parent)

    result = SerializeAdminConcept.(parent.reload)

    assert_equal 2, result[:children_count]
  end

  test "includes ancestors array ordered from root to parent" do
    grandparent = create(:concept, title: "Grandparent", slug: "grandparent")
    parent = create(:concept, title: "Parent", slug: "parent", parent: grandparent)
    child = create(:concept, title: "Child", parent: parent)

    result = SerializeAdminConcept.(child)

    assert_equal 2, result[:ancestors].length
    assert_equal({ id: grandparent.id, title: "Grandparent", slug: "grandparent" }, result[:ancestors][0])
    assert_equal({ id: parent.id, title: "Parent", slug: "parent" }, result[:ancestors][1])
  end

  test "ancestors is empty for root concept" do
    concept = create(:concept)

    result = SerializeAdminConcept.(concept)

    assert_empty result[:ancestors]
  end
end
