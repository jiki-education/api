require "test_helper"

class Concept::SearchTest < ActiveSupport::TestCase
  test "no options returns all concepts paginated" do
    concept_b = create :concept, slug: "bravo"
    concept_a = create :concept, slug: "alpha"

    result = Concept::Search.()

    # Results ordered alphabetically by slug
    assert_equal [concept_a, concept_b], result.to_a
  end

  test "query: search for partial slug match" do
    concept_1 = create :concept, slug: "strings-and-text"
    concept_2 = create :concept, slug: "arrays"
    concept_3 = create :concept, slug: "string-manipulation"

    assert_equal [concept_2, concept_3, concept_1], Concept::Search.(query: "").to_a
    assert_equal [concept_3, concept_1], Concept::Search.(query: "string").to_a
    assert_equal [concept_2], Concept::Search.(query: "arrays").to_a
    assert_empty Concept::Search.(query: "xyz").to_a
  end

  test "query search is case insensitive" do
    concept = create :concept, slug: "strings-and-text"

    assert_equal [concept], Concept::Search.(query: "strings").to_a
    assert_equal [concept], Concept::Search.(query: "STRINGS").to_a
    assert_equal [concept], Concept::Search.(query: "StRiNgS").to_a
  end

  test "pagination" do
    concept_b = create :concept, slug: "bravo"
    concept_a = create :concept, slug: "alpha"

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

  test "sanitizes SQL wildcards in query search" do
    concept1 = create :concept, slug: "100%-complete"
    create :concept, slug: "arrays"
    concept3 = create :concept, slug: "string_manipulation"

    # Search for "%" should match literal "%" not act as wildcard
    assert_equal [concept1], Concept::Search.(query: "%").to_a

    # Search for "_" should match literal "_" not act as single-character wildcard
    assert_equal [concept3], Concept::Search.(query: "_").to_a

    # Wildcards should not match everything
    assert_empty Concept::Search.(query: "%%").to_a
  end

  test "user: returns all concepts ordered by unlocked first then alphabetically" do
    concept_zebra = create :concept, slug: "zebra"
    concept_middle = create :concept, slug: "middle"
    concept_apple = create :concept, slug: "apple"
    user = create :user

    Concept::UnlockForUser.(concept_zebra, user)
    Concept::UnlockForUser.(concept_apple, user)

    result = Concept::Search.(user:).to_a
    # Unlocked first (apple, zebra alphabetically), then locked (middle)
    assert_equal [concept_apple, concept_zebra, concept_middle], result
  end

  test "user: nil returns all concepts" do
    concept_b = create :concept, slug: "bravo"
    concept_a = create :concept, slug: "alpha"
    user = create :user

    Concept::UnlockForUser.(concept_a, user)

    assert_equal [concept_a, concept_b], Concept::Search.(user: nil).to_a
  end

  test "user: with query filter returns all matching concepts with unlocked-first ordering" do
    concept_strings = create :concept, slug: "strings"
    concept_string_arrays = create :concept, slug: "string-arrays"
    create :concept, slug: "arrays"
    user = create :user

    Concept::UnlockForUser.(concept_strings, user)
    # concept_string_arrays is locked

    result = Concept::Search.(user:, query: "string").to_a
    # Unlocked first (strings), then locked (string-arrays)
    assert_equal [concept_strings, concept_string_arrays], result
  end

  test "user: respects pagination with unlocked-first ordering" do
    concept_alpha = create :concept, slug: "alpha"
    concept_bravo = create :concept, slug: "bravo"
    concept_charlie = create :concept, slug: "charlie"
    user = create :user

    # Only unlock charlie (should appear first)
    Concept::UnlockForUser.(concept_charlie, user)

    result = Concept::Search.(user:, page: 1, per: 2).to_a
    # First page: charlie (unlocked), then alpha (locked, alphabetically first)
    assert_equal [concept_charlie, concept_alpha], result

    result = Concept::Search.(user:, page: 2, per: 2).to_a
    # Second page: bravo (locked)
    assert_equal [concept_bravo], result
  end

  test "orders concepts by slug alphabetically" do
    concept_z = create :concept, slug: "zulu"
    concept_a = create :concept, slug: "alpha"
    concept_m = create :concept, slug: "mike"
    concept_b = create :concept, slug: "bravo"

    result = Concept::Search.().to_a

    assert_equal [concept_a, concept_b, concept_m, concept_z], result
    assert_equal %w[alpha bravo mike zulu], result.map(&:slug)
  end

  test "slugs: filters by single slug" do
    concept_1 = create :concept, slug: "alpha-concept"
    create :concept, slug: "bravo-concept"

    assert_equal [concept_1], Concept::Search.(slugs: "alpha-concept").to_a
  end

  test "slugs: filters by multiple slugs (comma-separated)" do
    concept_1 = create :concept, slug: "alpha-concept"
    create :concept, slug: "bravo-concept"
    concept_3 = create :concept, slug: "charlie-concept"

    result = Concept::Search.(slugs: "alpha-concept,charlie-concept").to_a
    assert_equal [concept_1, concept_3], result
  end

  test "slugs: handles whitespace around slugs" do
    concept_1 = create :concept, slug: "alpha-concept"
    concept_2 = create :concept, slug: "bravo-concept"

    result = Concept::Search.(slugs: " alpha-concept , bravo-concept ").to_a
    assert_equal [concept_1, concept_2], result
  end

  test "slugs: returns empty for non-existent slugs" do
    create :concept, slug: "alpha-concept"

    assert_empty Concept::Search.(slugs: "non-existent").to_a
  end

  test "slugs: combined with user returns all matching with unlocked-first ordering" do
    concept_alpha = create :concept, slug: "alpha-concept"
    concept_bravo = create :concept, slug: "bravo-concept"
    user = create :user

    Concept::UnlockForUser.(concept_alpha, user)
    # concept_bravo is NOT unlocked

    # Both slugs requested, unlocked first then locked
    result = Concept::Search.(slugs: "alpha-concept,bravo-concept", user:).to_a
    assert_equal [concept_alpha, concept_bravo], result
  end

  test "slugs: combined with query filter" do
    concept_1 = create :concept, slug: "string-basics"
    create :concept, slug: "array-basics"
    create :concept, slug: "string-advanced"

    # Filter by slugs AND query - only string-basics matches both
    result = Concept::Search.(slugs: "string-basics,array-basics", query: "string").to_a
    assert_equal [concept_1], result
  end
end
