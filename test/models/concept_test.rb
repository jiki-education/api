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
