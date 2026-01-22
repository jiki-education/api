require "test_helper"

class SerializeConceptsTest < ActiveSupport::TestCase
  test "serializes basic concept fields" do
    concept = create(:concept,
      title: "Arrays",
      slug: "arrays",
      description: "Learn about arrays",
      standard_video_provider: "youtube",
      standard_video_id: "abc123",
      premium_video_provider: "mux",
      premium_video_id: "def456")

    result = SerializeConcepts.([concept])

    assert_equal 1, result.length
    assert_equal "Arrays", result[0][:title]
    assert_equal "arrays", result[0][:slug]
    assert_equal "Learn about arrays", result[0][:description]
    assert_equal "youtube", result[0][:standard_video_provider]
    assert_equal "abc123", result[0][:standard_video_id]
    assert_equal "mux", result[0][:premium_video_provider]
    assert_equal "def456", result[0][:premium_video_id]
    assert result[0][:user_may_access]
  end

  test "does not include id" do
    concept = create(:concept)

    result = SerializeConcepts.([concept])

    refute result[0].key?(:id)
  end

  test "does not include content_html or content_markdown" do
    concept = create(:concept)

    result = SerializeConcepts.([concept])

    refute result[0].key?(:content_html)
    refute result[0].key?(:content_markdown)
  end

  test "includes children_count" do
    parent = create(:concept)
    create(:concept, parent: parent)
    create(:concept, parent: parent)

    result = SerializeConcepts.([parent.reload])

    assert_equal 2, result[0][:children_count]
  end

  test "does not include ancestors in collection" do
    parent = create(:concept)
    child = create(:concept, parent: parent)

    result = SerializeConcepts.([child])

    refute result[0].key?(:ancestors)
  end

  test "user_may_access is true when no user provided" do
    concept = create(:concept)

    result = SerializeConcepts.([concept])

    assert result[0][:user_may_access]
  end

  test "user_may_access is true for unlocked concepts" do
    concept = create(:concept)
    user = create(:user)
    Concept::UnlockForUser.(concept, user)

    result = SerializeConcepts.([concept], for_user: user)

    assert result[0][:user_may_access]
  end

  test "user_may_access is false for locked concepts" do
    concept = create(:concept)
    user = create(:user)

    result = SerializeConcepts.([concept], for_user: user)

    refute result[0][:user_may_access]
  end

  test "handles mix of locked and unlocked concepts" do
    concept_unlocked = create(:concept, title: "Unlocked Concept")
    concept_locked = create(:concept, title: "Locked Concept")
    user = create(:user)
    Concept::UnlockForUser.(concept_unlocked, user)

    result = SerializeConcepts.([concept_unlocked, concept_locked], for_user: user)

    assert_equal 2, result.length
    assert result[0][:user_may_access]
    refute result[1][:user_may_access]
  end
end
