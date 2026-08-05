require "test_helper"

class Challenge::SearchTest < ActiveSupport::TestCase
  test "no options returns all challenges paginated and ordered by slug" do
    challenge_b = create :challenge, slug: "bravo"
    challenge_a = create :challenge, slug: "alpha"

    assert_equal [challenge_a, challenge_b], Challenge::Search.().to_a
  end

  test "query: search for partial slug match" do
    challenge_1 = create :challenge, slug: "calculator"
    challenge_2 = create :challenge, slug: "todo-list"
    challenge_3 = create :challenge, slug: "scientific-calculator"

    assert_equal [challenge_1, challenge_3, challenge_2], Challenge::Search.(query: "").to_a
    assert_equal [challenge_1, challenge_3], Challenge::Search.(query: "calculator").to_a
    assert_equal [challenge_2], Challenge::Search.(query: "todo").to_a
    assert_empty Challenge::Search.(query: "xyz").to_a
  end

  test "query search is case insensitive" do
    challenge = create :challenge, slug: "calculator"

    assert_equal [challenge], Challenge::Search.(query: "calculator").to_a
    assert_equal [challenge], Challenge::Search.(query: "CALCULATOR").to_a
    assert_equal [challenge], Challenge::Search.(query: "CaLcUlAtOr").to_a
  end

  test "pagination" do
    challenge_1 = create :challenge, slug: "alpha"
    challenge_2 = create :challenge, slug: "bravo"

    assert_equal [challenge_1], Challenge::Search.(page: 1, per: 1).to_a
    assert_equal [challenge_2], Challenge::Search.(page: 2, per: 1).to_a
  end

  test "returns paginated collection with correct metadata" do
    Prosopite.finish # Stop scan before creating test data
    5.times { create :challenge }

    Prosopite.scan # Resume scan for the actual search
    result = Challenge::Search.(page: 2, per: 2)

    assert_equal 2, result.current_page
    assert_equal 5, result.total_count
    assert_equal 3, result.total_pages
    assert_equal 2, result.size
  end

  test "sanitizes SQL wildcards in query search" do
    challenge1 = create :challenge, slug: "100%-complete"
    create :challenge, slug: "arrays"
    challenge3 = create :challenge, slug: "string_manipulation"

    # Search for "%" should match literal "%" not act as wildcard
    assert_equal [challenge1], Challenge::Search.(query: "%").to_a

    # Search for "_" should match literal "_" not act as single-character wildcard
    assert_equal [challenge3], Challenge::Search.(query: "_").to_a

    # Wildcards should not match everything
    assert_empty Challenge::Search.(query: "%%").to_a
  end

  test "user: orders unlocked challenges first, then locked challenges, all by slug" do
    challenge_zebra = create :challenge, slug: "zebra"
    challenge_apple = create :challenge, slug: "apple"
    challenge_middle = create :challenge, slug: "middle"
    user = create :user

    create :user_challenge, user:, challenge: challenge_zebra
    create :user_challenge, user:, challenge: challenge_middle

    result = Challenge::Search.(user:).to_a

    # Unlocked first (middle, zebra), then locked (apple)
    assert_equal [challenge_middle, challenge_zebra, challenge_apple], result
  end

  test "user: with no unlocked challenges returns all challenges ordered by slug" do
    challenge_zebra = create :challenge, slug: "zebra"
    challenge_apple = create :challenge, slug: "apple"
    user = create :user

    assert_equal [challenge_apple, challenge_zebra], Challenge::Search.(user:).to_a
  end

  test "user: with query search maintains unlocked-first ordering" do
    challenge_calc1 = create :challenge, slug: "basic-calculator"
    challenge_calc2 = create :challenge, slug: "scientific-calculator"
    challenge_calc3 = create :challenge, slug: "graphing-calculator"
    user = create :user

    create :user_challenge, user:, challenge: challenge_calc2

    result = Challenge::Search.(query: "calculator", user:).to_a

    # scientific (unlocked) first, then the locked ones by slug
    assert_equal [challenge_calc2, challenge_calc1, challenge_calc3], result
  end

  test "user: returns challenges even when other users have user_challenges for them" do
    challenge = create :challenge
    user = create :user
    other_user = create :user

    # Another user has started this challenge, but our user has not
    create :user_challenge, user: other_user, challenge: challenge

    assert_equal [challenge], Challenge::Search.(user:).to_a
  end

  test "user: pagination works correctly with user filtering" do
    challenge_1 = create :challenge, slug: "alpha"
    challenge_2 = create :challenge, slug: "bravo"
    challenge_3 = create :challenge, slug: "charlie"
    user = create :user

    # charlie is unlocked, so it sorts ahead of the locked alpha and bravo
    create :user_challenge, user:, challenge: challenge_3

    assert_equal [challenge_3, challenge_1], Challenge::Search.(user:, page: 1, per: 2).to_a
    assert_equal [challenge_2], Challenge::Search.(user:, page: 2, per: 2).to_a
  end
end
