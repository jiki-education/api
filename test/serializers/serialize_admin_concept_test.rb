require "test_helper"

class SerializeAdminConceptTest < ActiveSupport::TestCase
  test "serializes concept with all fields" do
    concept = create(:concept,
      title: "Loops",
      slug: "loops",
      description: "Learn about loops",
      content_markdown: "# Loops",
      standard_video_provider: "youtube",
      standard_video_id: "abc123",
      premium_video_provider: "mux",
      premium_video_id: "def456")

    result = SerializeAdminConcept.(concept)

    assert_equal concept.id, result[:id]
    assert_equal "Loops", result[:title]
    assert_equal "loops", result[:slug]
    assert_equal "Learn about loops", result[:description]
    assert_equal "# Loops", result[:content_markdown]
    assert_equal "youtube", result[:standard_video_provider]
    assert_equal "abc123", result[:standard_video_id]
    assert_equal "mux", result[:premium_video_provider]
    assert_equal "def456", result[:premium_video_id]
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
