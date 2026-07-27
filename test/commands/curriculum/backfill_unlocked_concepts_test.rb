require "test_helper"

class Curriculum::BackfillUnlockedConceptsTest < ActiveSupport::TestCase
  test "unlocks concepts whose lesson the user has already completed" do
    lesson = create(:lesson, :exercise)
    concept = create(:concept, unlocked_by_lesson: lesson)
    user = create(:user)
    create(:user_lesson, :completed, user:, lesson:)

    Curriculum::BackfillUnlockedConcepts.()

    assert_equal [concept.id], user.data.reload.unlocked_concept_ids
  end

  test "unlocks every concept taught by a completed lesson" do
    lesson = create(:lesson, :exercise)
    concept1 = create(:concept, unlocked_by_lesson: lesson)
    concept2 = create(:concept, unlocked_by_lesson: lesson)
    user = create(:user)
    create(:user_lesson, :completed, user:, lesson:)

    Curriculum::BackfillUnlockedConcepts.()

    assert_equal [concept1.id, concept2.id].sort, user.data.reload.unlocked_concept_ids
  end

  test "does not unlock concepts for lessons the user only started" do
    lesson = create(:lesson, :exercise)
    create(:concept, unlocked_by_lesson: lesson)
    user = create(:user)
    create(:user_lesson, user:, lesson:, completed_at: nil)

    Curriculum::BackfillUnlockedConcepts.()

    assert_empty user.data.reload.unlocked_concept_ids
  end

  test "does not unlock concepts with no unlocking lesson" do
    create(:concept, unlocked_by_lesson: nil)
    lesson = create(:lesson, :exercise)
    user = create(:user)
    create(:user_lesson, :completed, user:, lesson:)

    Curriculum::BackfillUnlockedConcepts.()

    assert_empty user.data.reload.unlocked_concept_ids
  end

  test "preserves already-unlocked concepts (append-only)" do
    lesson = create(:lesson, :exercise)
    concept = create(:concept, unlocked_by_lesson: lesson)
    other_concept = create(:concept, unlocked_by_lesson: nil)
    user = create(:user)
    create(:user_lesson, :completed, user:, lesson:)
    # Simulate a concept unlocked through some other path.
    user.data.update!(unlocked_concept_ids: [other_concept.id])

    Curriculum::BackfillUnlockedConcepts.()

    assert_equal [concept.id, other_concept.id].sort, user.data.reload.unlocked_concept_ids
  end

  test "is idempotent - running twice keeps identical values and updates nothing the second time" do
    lesson = create(:lesson, :exercise)
    create(:concept, unlocked_by_lesson: lesson)
    user = create(:user)
    create(:user_lesson, :completed, user:, lesson:)

    Curriculum::BackfillUnlockedConcepts.()
    first = user.data.reload.unlocked_concept_ids

    updated_rows = Curriculum::BackfillUnlockedConcepts.()

    assert_equal 0, updated_rows
    assert_equal first, user.data.reload.unlocked_concept_ids
  end

  test "only affects users who completed the relevant lesson" do
    lesson = create(:lesson, :exercise)
    concept = create(:concept, unlocked_by_lesson: lesson)
    completed_user = create(:user)
    create(:user_lesson, :completed, user: completed_user, lesson:)
    untouched_user = create(:user)

    Curriculum::BackfillUnlockedConcepts.()

    assert_equal [concept.id], completed_user.data.reload.unlocked_concept_ids
    assert_empty untouched_user.data.reload.unlocked_concept_ids
  end

  test "returns the number of updated user_data rows" do
    lesson = create(:lesson, :exercise)
    create(:concept, unlocked_by_lesson: lesson)
    user1 = create(:user)
    user2 = create(:user)
    create(:user_lesson, :completed, user: user1, lesson:)
    create(:user_lesson, :completed, user: user2, lesson:)

    assert_equal 2, Curriculum::BackfillUnlockedConcepts.()
  end
end
