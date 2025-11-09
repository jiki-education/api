require "test_helper"

class Concept::UpdateTest < ActiveSupport::TestCase
  test "updates concept with valid attributes" do
    concept = create :concept, title: "Original"

    Concept::Update.(concept, { title: "Updated" })

    assert_equal "Updated", concept.title
  end

  test "updates markdown and regenerates HTML" do
    concept = create :concept, content_markdown: "# Original"

    Concept::Update.(concept, { content_markdown: "# Updated" })

    assert_equal "# Updated", concept.content_markdown
    assert_includes concept.content_html, "Updated"
  end

  test "raises validation error for invalid attributes" do
    concept = create :concept

    assert_raises ActiveRecord::RecordInvalid do
      Concept::Update.(concept, { title: "" })
    end
  end

  test "returns the updated concept" do
    concept = create :concept

    result = Concept::Update.(concept, { title: "New Title" })

    assert_equal concept, result
    assert_equal "New Title", result.title
  end
end
