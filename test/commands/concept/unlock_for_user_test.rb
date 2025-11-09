require 'test_helper'

class Concept::UnlockForUserTest < ActiveSupport::TestCase
  test "adds concept ID to user data unlocked_concept_ids" do
    user = create :user
    concept = create :concept

    assert_difference -> { user.data.reload.unlocked_concept_ids.length }, 1 do
      Concept::UnlockForUser.(concept, user)
    end

    assert_includes user.data.unlocked_concept_ids, concept.id
  end

  test "is idempotent - calling multiple times doesn't add duplicates" do
    user = create :user
    concept = create :concept

    # Call multiple times
    5.times { Concept::UnlockForUser.(concept, user) }

    # Should only have one entry
    assert_equal 1, user.data.unlocked_concept_ids.count(concept.id)
    assert_equal [concept.id], user.data.unlocked_concept_ids
  end

  test "multiple users can unlock same concept" do
    user1 = create :user
    user2 = create :user
    concept = create :concept

    Concept::UnlockForUser.(concept, user1)
    Concept::UnlockForUser.(concept, user2)

    assert_includes user1.data.unlocked_concept_ids, concept.id
    assert_includes user2.data.unlocked_concept_ids, concept.id
  end

  test "user can unlock multiple concepts" do
    user = create :user
    concept1 = create :concept
    concept2 = create :concept

    Concept::UnlockForUser.(concept1, user)
    Concept::UnlockForUser.(concept2, user)

    assert_includes user.data.unlocked_concept_ids, concept1.id
    assert_includes user.data.unlocked_concept_ids, concept2.id
    assert_equal 2, user.data.unlocked_concept_ids.length
  end

  test "reloads user data after unlocking" do
    user = create :user
    concept = create :concept

    # Store reference to data object before unlocking
    data_before = user.data
    initial_array = data_before.unlocked_concept_ids.dup

    Concept::UnlockForUser.(concept, user)

    # The same object should have updated array
    assert_includes data_before.unlocked_concept_ids, concept.id
    refute_equal initial_array, data_before.unlocked_concept_ids
  end

  test "emits concept_unlocked event when concept is unlocked" do
    user = create :user
    concept = create :concept, slug: "variables", title: "Variables"

    Current.reset
    Concept::UnlockForUser.(concept, user)

    events = Current.events
    assert_equal 1, events.length

    event = events.first
    assert_equal "concept_unlocked", event[:type]
    assert_equal "variables", event[:data][:concept][:slug]
    assert_equal "Variables", event[:data][:concept][:title]
  end

  test "does not emit event when concept already unlocked (idempotent)" do
    user = create :user
    concept = create :concept

    # Unlock once
    Concept::UnlockForUser.(concept, user)

    # Reset events and unlock again
    Current.reset
    Concept::UnlockForUser.(concept, user)

    # Should not emit event on second unlock
    assert_nil Current.events
  end
end
