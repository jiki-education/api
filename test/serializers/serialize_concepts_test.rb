require "test_helper"

class SerializeConceptsTest < ActiveSupport::TestCase
  test "serializes basic concept fields" do
    concept = create(:concept, slug: "arrays")

    result = SerializeConcepts.([concept])

    assert_equal [{ slug: "arrays", user_may_access: true }], result
  end

  # Title and description are owned by the front-end curriculum catalogue.
  test "does not include title or description" do
    concept = create(:concept)

    result = SerializeConcepts.([concept])

    refute result[0].key?(:title)
    refute result[0].key?(:description)
  end

  test "does not include video_data" do
    concept = create(:concept)

    result = SerializeConcepts.([concept])

    refute result[0].key?(:video_data)
  end

  test "does not include id" do
    concept = create(:concept)

    result = SerializeConcepts.([concept])

    refute result[0].key?(:id)
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
    concept_unlocked = create(:concept)
    concept_locked = create(:concept)
    user = create(:user)
    Concept::UnlockForUser.(concept_unlocked, user)

    result = SerializeConcepts.([concept_unlocked, concept_locked], for_user: user)

    assert_equal 2, result.length
    assert result[0][:user_may_access]
    refute result[1][:user_may_access]
  end
end
