require "test_helper"

class Concept::SearchTest < ActiveSupport::TestCase
  test "no options returns all concepts paginated" do
    # Use explicit titles to ensure deterministic alphabetical ordering
    concept_b = create :concept, title: "Bravo"
    concept_a = create :concept, title: "Alpha"

    result = Concept::Search.()

    # Results ordered alphabetically by title
    assert_equal [concept_a, concept_b], result.to_a
  end

  test "title: search for partial title match" do
    concept_1 = create :concept, title: "Strings and Text"
    concept_2 = create :concept, title: "Arrays"
    concept_3 = create :concept, title: "String Manipulation"

    # Results ordered alphabetically by title
    assert_equal [concept_2, concept_3, concept_1], Concept::Search.(title: "").to_a
    assert_equal [concept_3, concept_1], Concept::Search.(title: "String").to_a
    assert_equal [concept_2], Concept::Search.(title: "Arrays").to_a
    assert_empty Concept::Search.(title: "xyz").to_a
  end

  test "title search is case insensitive" do
    concept = create :concept, title: "Strings and Text"

    assert_equal [concept], Concept::Search.(title: "strings").to_a
    assert_equal [concept], Concept::Search.(title: "STRINGS").to_a
    assert_equal [concept], Concept::Search.(title: "StRiNgS").to_a
  end

  test "pagination" do
    # Use explicit titles to ensure deterministic alphabetical ordering
    concept_b = create :concept, title: "Bravo"
    concept_a = create :concept, title: "Alpha"

    # Results ordered alphabetically by title
    assert_equal [concept_a], Concept::Search.(page: 1, per: 1).to_a
    assert_equal [concept_b], Concept::Search.(page: 2, per: 1).to_a
  end

  test "returns paginated collection with correct metadata" do
    Prosopite.finish # Disable N+1 detection for this test due to FriendlyId slug checks
    5.times { create :concept }

    result = Concept::Search.(page: 2, per: 2)

    assert_equal 2, result.current_page
    assert_equal 5, result.total_count
    assert_equal 3, result.total_pages
    assert_equal 2, result.size
  end

  test "sanitizes SQL wildcards in title search" do
    concept1 = create :concept, title: "100% Complete"
    create :concept, title: "Arrays"
    concept3 = create :concept, title: "String_Manipulation"

    # Search for "%" should match literal "%" not act as wildcard
    result = Concept::Search.(title: "%").to_a
    assert_equal [concept1], result

    # Search for "_" should match literal "_" not act as single-character wildcard
    result = Concept::Search.(title: "_").to_a
    assert_equal [concept3], result

    # Wildcards should not match everything
    result = Concept::Search.(title: "%%").to_a
    assert_empty result
  end

  test "user: filters to only unlocked concepts" do
    concept_1 = create :concept, title: "Zebra"
    create :concept, title: "Middle"
    concept_3 = create :concept, title: "Apple"
    user = create :user

    Concept::UnlockForUser.(concept_1, user)
    Concept::UnlockForUser.(concept_3, user)

    result = Concept::Search.(user:).to_a
    # Results ordered alphabetically by title
    assert_equal [concept_3, concept_1], result
  end

  test "user: nil returns all concepts" do
    # Use explicit titles to ensure deterministic alphabetical ordering
    concept_b = create :concept, title: "Bravo"
    concept_a = create :concept, title: "Alpha"
    user = create :user

    Concept::UnlockForUser.(concept_a, user)

    result = Concept::Search.(user: nil).to_a
    # Results ordered alphabetically by title
    assert_equal [concept_a, concept_b], result
  end

  test "user: with title filter returns only unlocked matching concepts" do
    concept_1 = create :concept, title: "Strings"
    create :concept, title: "String Arrays"
    concept_3 = create :concept, title: "Arrays"
    user = create :user

    Concept::UnlockForUser.(concept_1, user)
    Concept::UnlockForUser.(concept_3, user)

    result = Concept::Search.(user:, title: "String").to_a
    assert_equal [concept_1], result
  end

  test "user: respects pagination" do
    # Use explicit alphabetically ordered titles to ensure deterministic pagination
    concept_1 = create :concept, title: "Alpha"
    concept_2 = create :concept, title: "Bravo"
    concept_3 = create :concept, title: "Charlie"
    user = create :user

    Concept::UnlockForUser.(concept_1, user)
    Concept::UnlockForUser.(concept_2, user)
    Concept::UnlockForUser.(concept_3, user)

    result = Concept::Search.(user:, page: 1, per: 2).to_a
    assert_equal [concept_1, concept_2], result

    result = Concept::Search.(user:, page: 2, per: 2).to_a
    assert_equal [concept_3], result
  end

  test "orders concepts by title alphabetically" do
    concept_z = create :concept, title: "Zulu"
    concept_a = create :concept, title: "Alpha"
    concept_m = create :concept, title: "Mike"
    concept_b = create :concept, title: "Bravo"

    result = Concept::Search.().to_a

    assert_equal [concept_a, concept_b, concept_m, concept_z], result
    assert_equal %w[Alpha Bravo Mike Zulu], result.map(&:title)
  end
end
