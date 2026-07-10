require "test_helper"

class Challenge::SearchTest < ActiveSupport::TestCase
  test "no options returns all challenges paginated and ordered by title" do
    challenge_1 = create :challenge, title: "Zebra App"
    challenge_2 = create :challenge, title: "Apple App"

    result = Challenge::Search.()

    assert_equal [challenge_2, challenge_1], result.to_a
  end

  test "title: search for partial title match" do
    challenge_1 = create :challenge, title: "Calculator App"
    challenge_2 = create :challenge, title: "Todo List"
    challenge_3 = create :challenge, title: "Scientific Calculator"

    assert_equal [challenge_1, challenge_3, challenge_2], Challenge::Search.(title: "").to_a
    assert_equal [challenge_1, challenge_3], Challenge::Search.(title: "Calculator").to_a
    assert_equal [challenge_2], Challenge::Search.(title: "Todo").to_a
    assert_empty Challenge::Search.(title: "xyz").to_a
  end

  test "title search is case insensitive" do
    challenge = create :challenge, title: "Calculator App"

    assert_equal [challenge], Challenge::Search.(title: "calculator").to_a
    assert_equal [challenge], Challenge::Search.(title: "CALCULATOR").to_a
    assert_equal [challenge], Challenge::Search.(title: "CaLcUlAtOr").to_a
  end

  test "pagination" do
    challenge_1 = create :challenge, title: "Apple"
    challenge_2 = create :challenge, title: "Banana"

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

  test "sanitizes SQL wildcards in title search" do
    challenge1 = create :challenge, title: "100% Complete"
    create :challenge, title: "Todo List"
    challenge3 = create :challenge, title: "String_Parser"

    # Search for "%" should match literal "%" not act as wildcard
    result = Challenge::Search.(title: "%").to_a
    assert_equal [challenge1], result

    # Search for "_" should match literal "_" not act as single-character wildcard
    result = Challenge::Search.(title: "_").to_a
    assert_equal [challenge3], result

    # Wildcards should not match everything
    result = Challenge::Search.(title: "%%").to_a
    assert_empty result
  end

  test "user: orders unlocked challenges first, then locked challenges, all by title" do
    challenge_zebra = create :challenge, title: "Zebra Challenge"
    challenge_apple = create :challenge, title: "Apple Challenge"
    challenge_middle = create :challenge, title: "Middle Challenge"
    user = create :user

    # User unlocks Zebra and Middle
    create :user_challenge, user:, challenge: challenge_zebra
    create :user_challenge, user:, challenge: challenge_middle

    result = Challenge::Search.(user:).to_a

    # Unlocked challenges first (Middle, Zebra), then locked (Apple)
    assert_equal [challenge_middle, challenge_zebra, challenge_apple], result
  end

  test "user: with no unlocked challenges returns all challenges ordered by title" do
    challenge_zebra = create :challenge, title: "Zebra Challenge"
    challenge_apple = create :challenge, title: "Apple Challenge"
    user = create :user

    result = Challenge::Search.(user:).to_a

    assert_equal [challenge_apple, challenge_zebra], result
  end

  test "user: with title search maintains unlocked-first ordering" do
    challenge_calc1 = create :challenge, title: "Calculator App"
    challenge_calc2 = create :challenge, title: "Scientific Calculator"
    challenge_calc3 = create :challenge, title: "Basic Calculator"
    user = create :user

    # User only unlocks Scientific Calculator
    create :user_challenge, user:, challenge: challenge_calc2

    result = Challenge::Search.(title: "Calculator", user:).to_a

    # Scientific Calculator (unlocked) first, then locked ones by title
    assert_equal [challenge_calc2, challenge_calc3, challenge_calc1], result
  end

  test "user: returns challenges even when other users have user_challenges for them" do
    challenge = create :challenge, title: "Shared Challenge"
    user = create :user
    other_user = create :user

    # Another user has started this challenge, but our user has not
    create :user_challenge, user: other_user, challenge: challenge

    result = Challenge::Search.(user:).to_a

    assert_equal [challenge], result
  end

  test "user: pagination works correctly with user filtering" do
    challenge_1 = create :challenge, title: "Apple"
    challenge_2 = create :challenge, title: "Banana"
    challenge_3 = create :challenge, title: "Cherry"
    user = create :user

    # User unlocks Cherry (should appear first)
    create :user_challenge, user:, challenge: challenge_3

    result_page1 = Challenge::Search.(user:, page: 1, per: 2).to_a
    result_page2 = Challenge::Search.(user:, page: 2, per: 2).to_a

    # First page: Cherry (unlocked), Apple (locked)
    assert_equal [challenge_3, challenge_1], result_page1
    # Second page: Banana (locked)
    assert_equal [challenge_2], result_page2
  end
end
