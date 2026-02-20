require "test_helper"

class Concept::CreateTest < ActiveSupport::TestCase
  test "creates concept with valid attributes" do
    attributes = {
      title: "Strings",
      description: "Learn about strings",
      content_markdown: "# Strings\n\nStrings are text."
    }

    concept = Concept::Create.(attributes)

    assert_equal "Strings", concept.title
    assert_equal "Learn about strings", concept.description
    assert_equal "# Strings\n\nStrings are text.", concept.content_markdown
    assert concept.persisted?
  end

  test "creates concept with video data" do
    video_data = [{ provider: "youtube", id: "abc123" }, { provider: "mux", id: "def456" }]
    attributes = {
      title: "Strings",
      description: "Learn about strings",
      content_markdown: "# Strings",
      video_data: video_data
    }

    concept = Concept::Create.(attributes)

    assert_equal video_data, concept.video_data
  end

  test "raises validation error for invalid attributes" do
    attributes = { title: "" }

    assert_raises ActiveRecord::RecordInvalid do
      Concept::Create.(attributes)
    end
  end

  test "creates concept with parent" do
    parent = create(:concept)
    attributes = {
      title: "Child Concept",
      description: "A child concept",
      content_markdown: "# Child",
      parent_concept_id: parent.id
    }

    concept = Concept::Create.(attributes)

    assert_equal parent, concept.parent
    assert_equal 1, parent.reload.children_count
  end
end
