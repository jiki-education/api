require "test_helper"

class ConceptTest < ActiveSupport::TestCase
  test "valid factory" do
    assert build(:concept).valid?
  end

  test "requires title" do
    concept = build(:concept, title: nil)
    refute concept.valid?
  end

  test "requires description" do
    concept = build(:concept, description: nil)
    refute concept.valid?
  end

  test "requires content_markdown" do
    concept = build(:concept, content_markdown: nil)
    refute concept.valid?
  end

  test "requires unique slug" do
    create(:concept, slug: "strings")
    duplicate = build(:concept, slug: "strings")
    refute duplicate.valid?
  end

  test "auto-generates slug from title on create" do
    concept = create(:concept, title: "Hello World", slug: nil)
    assert_equal "hello-world", concept.slug
  end

  test "preserves provided slug" do
    concept = create(:concept, title: "Hello World", slug: "custom-slug")
    assert_equal "custom-slug", concept.slug
  end

  test "converts markdown to HTML on create" do
    concept = create(:concept, content_markdown: "# Hello\n\nWorld")
    assert_includes concept.content_html, "<h1"
    assert_includes concept.content_html, "Hello"
    assert_includes concept.content_html, "<p"
    assert_includes concept.content_html, "World"
  end

  test "updates HTML when markdown changes" do
    concept = create(:concept, content_markdown: "# Original")
    assert_includes concept.content_html, "Original"

    concept.update!(content_markdown: "# Updated")
    assert_includes concept.content_html, "Updated"
    refute_includes concept.content_html, "Original"
  end

  test "does not update HTML when markdown unchanged" do
    concept = create(:concept)
    original_html = concept.content_html

    concept.update!(title: "New Title")
    assert_equal original_html, concept.content_html
  end

  test "validates video provider must be youtube or mux" do
    concept = build(:concept, standard_video_provider: "vimeo")
    refute concept.valid?

    concept.standard_video_provider = "youtube"
    assert concept.valid?

    concept.standard_video_provider = "mux"
    assert concept.valid?
  end

  test "allows nil video provider" do
    concept = build(:concept, standard_video_provider: nil)
    assert concept.valid?
  end

  test "to_param returns slug" do
    concept = create(:concept, slug: "strings")
    assert_equal "strings", concept.to_param
  end

  test "does not auto-regenerate slug when title changes" do
    concept = create(:concept, title: "Original Title", slug: "custom-slug")

    concept.update!(title: "Completely Different Title")

    assert_equal "custom-slug", concept.reload.slug
    refute_equal "completely-different-title", concept.slug
  end
end
