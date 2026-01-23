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
    assert_equal({
      title: "Arrays",
      slug: "arrays",
      description: "Learn about arrays",
      standard_video_provider: "youtube",
      standard_video_id: "abc123",
      premium_video_provider: "mux",
      premium_video_id: "def456",
      user_may_access: true
    }, result[0])
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
