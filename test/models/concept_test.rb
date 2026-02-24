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

  test "validates video_data provider must be youtube or mux" do
    concept = build(:concept, video_data: [{ provider: "vimeo", id: "abc" }])
    refute concept.valid?

    concept.video_data = [{ provider: "youtube", id: "abc" }]
    assert concept.valid?

    concept.video_data = [{ provider: "mux", id: "abc" }]
    assert concept.valid?
  end

  test "validates video_data must be an array" do
    concept = build(:concept, video_data: { provider: "youtube", id: "abc" })
    refute concept.valid?
  end

  test "validates video_data entries must have provider and id" do
    concept = build(:concept, video_data: [{ provider: "youtube" }])
    refute concept.valid?

    concept.video_data = [{ id: "abc" }]
    refute concept.valid?
  end

  test "allows nil video_data" do
    concept = build(:concept, video_data: nil)
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

  # Parent-child association tests
  test "can have a parent concept" do
    parent = create(:concept)
    child = create(:concept, parent: parent)

    assert_equal parent, child.parent
  end

  test "can have multiple children" do
    parent = create(:concept)
    child1 = create(:concept, parent: parent)
    child2 = create(:concept, parent: parent)

    assert_includes parent.children, child1
    assert_includes parent.children, child2
  end

  test "root concept has no parent" do
    concept = create(:concept)

    assert_nil concept.parent
    assert concept.root?
  end

  test "child concept is not root" do
    parent = create(:concept)
    child = create(:concept, parent: parent)

    refute child.root?
  end

  test "children_count is maintained by counter cache" do
    parent = create(:concept)
    assert_equal 0, parent.children_count

    child1 = create(:concept, parent: parent)
    assert_equal 1, parent.reload.children_count

    create(:concept, parent: parent)
    assert_equal 2, parent.reload.children_count

    child1.destroy!
    assert_equal 1, parent.reload.children_count
  end

  test "has_children? returns true when concept has children" do
    parent = create(:concept)
    create(:concept, parent: parent)

    assert parent.reload.has_children?
  end

  test "has_children? returns false when concept has no children" do
    concept = create(:concept)

    refute concept.has_children?
  end

  # Circular reference prevention tests
  test "cannot set self as parent" do
    concept = create(:concept)
    concept.parent_concept_id = concept.id

    refute concept.valid?
    assert_includes concept.errors[:parent_concept_id], "cannot be the concept itself"
  end

  test "cannot create circular reference with direct cycle" do
    parent = create(:concept)
    child = create(:concept, parent: parent)

    parent.parent = child

    refute parent.valid?
    assert_includes parent.errors[:parent_concept_id], "would create a circular reference"
  end

  test "cannot create circular reference with indirect cycle" do
    grandparent = create(:concept)
    parent = create(:concept, parent: grandparent)
    child = create(:concept, parent: parent)

    grandparent.parent = child

    refute grandparent.valid?
    assert_includes grandparent.errors[:parent_concept_id], "would create a circular reference"
  end

  # Ancestors tests
  test "ancestors returns all ancestors ordered from root to parent" do
    grandparent = create(:concept, title: "Grandparent")
    parent = create(:concept, title: "Parent", parent: grandparent)
    child = create(:concept, title: "Child", parent: parent)

    ancestors = child.ancestors

    assert_equal 2, ancestors.length
    assert_equal grandparent.id, ancestors[0].id
    assert_equal parent.id, ancestors[1].id
  end

  test "ancestors returns empty array for root concept" do
    concept = create(:concept)

    assert_empty concept.ancestors
  end

  test "ancestor_ids returns ancestor IDs ordered from root to parent" do
    grandparent = create(:concept)
    parent = create(:concept, parent: grandparent)
    child = create(:concept, parent: parent)

    ancestor_ids = child.ancestor_ids

    assert_equal [grandparent.id, parent.id], ancestor_ids
  end

  test "ancestor_ids returns empty array for root concept" do
    concept = create(:concept)

    assert_empty concept.ancestor_ids
  end

  # Deletion behavior tests
  test "deleting parent nullifies children parent_concept_id" do
    parent = create(:concept)
    child = create(:concept, parent: parent)

    parent.destroy!

    child.reload
    assert_nil child.parent_concept_id
    assert child.root?
  end

  # Foreign key constraint tests
  test "rejects non-existent parent_concept_id" do
    concept = create(:concept)

    assert_raises ActiveRecord::InvalidForeignKey do
      concept.update!(parent_concept_id: 999_999)
    end
  end

  # Depth limit tests
  test "rejects nesting deeper than 10 levels" do
    Prosopite.finish
    # Create chain of 10 concepts (depth 0-9)
    concepts = [create(:concept)]
    9.times do
      concepts << create(:concept, parent: concepts.last)
    end

    # 11th level (depth 10) should fail
    too_deep = build(:concept, parent: concepts.last)
    refute too_deep.valid?
    assert_includes too_deep.errors[:parent_concept_id], "would exceed maximum nesting depth of 10"
  end

  test "allows nesting up to 10 levels" do
    Prosopite.finish
    # Create chain of 9 concepts (depth 0-8)
    concepts = [create(:concept)]
    8.times do
      concepts << create(:concept, parent: concepts.last)
    end

    # 10th level (depth 9) should succeed
    tenth_level = build(:concept, parent: concepts.last)
    assert tenth_level.valid?
  end

  # Lesson concepts association tests
  test "can have many lessons through lesson_concepts" do
    concept = create(:concept)
    lesson1 = create(:lesson, :exercise)
    lesson2 = create(:lesson, :video)

    create(:lesson_concept, concept: concept, lesson: lesson1)
    create(:lesson_concept, concept: concept, lesson: lesson2)

    assert_equal 2, concept.lessons.count
    assert_includes concept.lessons, lesson1
    assert_includes concept.lessons, lesson2
  end

  test "destroying concept destroys lesson_concepts but not lessons" do
    concept = create(:concept)
    lesson = create(:lesson, :exercise)
    create(:lesson_concept, concept: concept, lesson: lesson)

    assert_difference "LessonConcept.count", -1 do
      assert_no_difference "Lesson.count" do
        concept.destroy!
      end
    end
  end

  # Related concepts tests
  test "related_concepts for root concept returns only children" do
    root = create(:concept)
    child1 = create(:concept, parent: root)
    child2 = create(:concept, parent: root)
    unrelated = create(:concept)

    related = root.reload.related_concepts

    assert_includes related, child1
    assert_includes related, child2
    refute_includes related, unrelated
    refute_includes related, root
  end

  test "related_concepts for leaf concept returns parent and siblings" do
    parent = create(:concept)
    child1 = create(:concept, parent: parent)
    child2 = create(:concept, parent: parent)
    child3 = create(:concept, parent: parent)

    related = child1.related_concepts

    assert_includes related, parent
    assert_includes related, child2
    assert_includes related, child3
    refute_includes related, child1
  end

  test "related_concepts for middle concept returns parent, children, and siblings" do
    grandparent = create(:concept)
    parent = create(:concept, parent: grandparent)
    sibling = create(:concept, parent: grandparent)
    child1 = create(:concept, parent: parent)
    child2 = create(:concept, parent: parent)

    related = parent.related_concepts

    assert_includes related, grandparent
    assert_includes related, sibling
    assert_includes related, child1
    assert_includes related, child2
    refute_includes related, parent
  end

  test "related_concepts limits to 6 results" do
    Prosopite.finish
    root = create(:concept)
    7.times { create(:concept, parent: root) }

    assert_equal 6, root.reload.related_concepts.size
  end

  test "related_concepts for isolated root returns empty" do
    root = create(:concept)

    assert_empty root.related_concepts
  end
end
