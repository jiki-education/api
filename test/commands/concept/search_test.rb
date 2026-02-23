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

  test "user: returns all concepts ordered by unlocked first then alphabetically" do
    concept_zebra = create :concept, title: "Zebra"
    concept_middle = create :concept, title: "Middle"
    concept_apple = create :concept, title: "Apple"
    user = create :user

    Concept::UnlockForUser.(concept_zebra, user)
    Concept::UnlockForUser.(concept_apple, user)

    result = Concept::Search.(user:).to_a
    # Unlocked first (Apple, Zebra alphabetically), then locked (Middle)
    assert_equal [concept_apple, concept_zebra, concept_middle], result
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

  test "user: with title filter returns all matching concepts with unlocked-first ordering" do
    concept_strings = create :concept, title: "Strings"
    concept_string_arrays = create :concept, title: "String Arrays"
    create :concept, title: "Arrays"
    user = create :user

    Concept::UnlockForUser.(concept_strings, user)
    # concept_string_arrays is locked

    result = Concept::Search.(user:, title: "String").to_a
    # Unlocked first (Strings), then locked (String Arrays)
    assert_equal [concept_strings, concept_string_arrays], result
  end

  test "user: respects pagination with unlocked-first ordering" do
    concept_alpha = create :concept, title: "Alpha"
    concept_bravo = create :concept, title: "Bravo"
    concept_charlie = create :concept, title: "Charlie"
    user = create :user

    # Only unlock Charlie (should appear first)
    Concept::UnlockForUser.(concept_charlie, user)

    result = Concept::Search.(user:, page: 1, per: 2).to_a
    # First page: Charlie (unlocked), then Alpha (locked, alphabetically first)
    assert_equal [concept_charlie, concept_alpha], result

    result = Concept::Search.(user:, page: 2, per: 2).to_a
    # Second page: Bravo (locked)
    assert_equal [concept_bravo], result
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

  test "parent_slug: filters by parent concept slug" do
    parent = create :concept, title: "Arrays"
    child_1 = create :concept, title: "Array Push", parent_concept_id: parent.id
    child_2 = create :concept, title: "Array Pop", parent_concept_id: parent.id
    create :concept, title: "Strings"

    result = Concept::Search.(parent_slug: parent.slug).to_a
    assert_equal [child_2, child_1], result
  end

  test "parent_slug: returns empty for non-existent parent slug" do
    create :concept, title: "Arrays"

    result = Concept::Search.(parent_slug: "non-existent").to_a
    assert_empty result
  end

  test "parent_slug: combined with title filter" do
    parent = create :concept, title: "Arrays"
    child_1 = create :concept, title: "Array Push", parent_concept_id: parent.id
    create :concept, title: "Array Pop", parent_concept_id: parent.id
    create :concept, title: "String Push"

    result = Concept::Search.(parent_slug: parent.slug, title: "Push").to_a
    assert_equal [child_1], result
  end

  test "slugs: filters by single slug" do
    concept_1 = create :concept, title: "Alpha", slug: "alpha-concept"
    create :concept, title: "Bravo", slug: "bravo-concept"

    result = Concept::Search.(slugs: "alpha-concept").to_a
    assert_equal [concept_1], result
  end

  test "slugs: filters by multiple slugs (comma-separated)" do
    concept_1 = create :concept, title: "Alpha", slug: "alpha-concept"
    create :concept, title: "Bravo", slug: "bravo-concept"
    concept_3 = create :concept, title: "Charlie", slug: "charlie-concept"

    result = Concept::Search.(slugs: "alpha-concept,charlie-concept").to_a
    assert_equal [concept_1, concept_3], result
  end

  test "slugs: handles whitespace around slugs" do
    concept_1 = create :concept, title: "Alpha", slug: "alpha-concept"
    concept_2 = create :concept, title: "Bravo", slug: "bravo-concept"

    result = Concept::Search.(slugs: " alpha-concept , bravo-concept ").to_a
    assert_equal [concept_1, concept_2], result
  end

  test "slugs: returns empty for non-existent slugs" do
    create :concept, title: "Alpha", slug: "alpha-concept"

    result = Concept::Search.(slugs: "non-existent").to_a
    assert_empty result
  end

  test "slugs: combined with user returns all matching with unlocked-first ordering" do
    concept_alpha = create :concept, title: "Alpha", slug: "alpha-concept"
    concept_bravo = create :concept, title: "Bravo", slug: "bravo-concept"
    user = create :user

    Concept::UnlockForUser.(concept_alpha, user)
    # concept_bravo is NOT unlocked

    # Both slugs requested, unlocked first then locked
    result = Concept::Search.(slugs: "alpha-concept,bravo-concept", user:).to_a
    assert_equal [concept_alpha, concept_bravo], result
  end

  test "slugs: combined with title filter" do
    concept_1 = create :concept, title: "String Basics", slug: "string-basics"
    create :concept, title: "Array Basics", slug: "array-basics"
    create :concept, title: "String Advanced", slug: "string-advanced"

    # Filter by slugs AND title - only string-basics matches both
    result = Concept::Search.(slugs: "string-basics,array-basics", title: "String").to_a
    assert_equal [concept_1], result
  end
end
