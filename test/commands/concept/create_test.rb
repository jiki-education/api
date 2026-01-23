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

  test "creates concept with video providers" do
    attributes = {
      title: "Strings",
      description: "Learn about strings",
      content_markdown: "# Strings",
      standard_video_provider: "youtube",
      standard_video_id: "abc123",
      premium_video_provider: "mux",
      premium_video_id: "def456"
    }

    concept = Concept::Create.(attributes)

    assert_equal "youtube", concept.standard_video_provider
    assert_equal "abc123", concept.standard_video_id
    assert_equal "mux", concept.premium_video_provider
    assert_equal "def456", concept.premium_video_id
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
