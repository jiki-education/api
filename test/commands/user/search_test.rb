require "test_helper"

class User::SearchTest < ActiveSupport::TestCase
  test "no options returns all users paginated ordered by name" do
    user_1 = create :user, name: "Zara"
    user_2 = create :user, name: "Alice"
    user_3 = create :user, name: "James"

    result = User::Search.()

    # Should be ordered by name, not ID
    assert_equal [user_2, user_3, user_1], result.to_a
  end

  test "name: search for partial name match" do
    user_1 = create :user, name: "Amy Smith"
    user_2 = create :user, name: "Chris Johnson"
    user_3 = create :user, name: "Amanda Jones"

    # Results ordered by name
    assert_equal [user_3, user_1, user_2], User::Search.(name: "").to_a
    assert_equal [user_3, user_1], User::Search.(name: "Am").to_a
    assert_equal [user_2], User::Search.(name: "Chris").to_a
    assert_empty User::Search.(name: "xyz").to_a
  end

  test "email: search for partial email match" do
    user_1 = create :user, name: "Zara", email: "amy@example.com"
    user_2 = create :user, name: "Yolanda", email: "chris@test.org"
    user_3 = create :user, name: "Xavier", email: "amanda@example.com"

    # Results ordered by name
    assert_equal [user_3, user_2, user_1], User::Search.(email: "").to_a
    assert_equal [user_3, user_1], User::Search.(email: "example").to_a
    assert_equal [user_2], User::Search.(email: "chris").to_a
    assert_empty User::Search.(email: "xyz").to_a
  end

  test "pagination" do
    user_1 = create :user, name: "Zara"
    user_2 = create :user, name: "Alice"

    # Ordered by name: Alice first, then Zara
    assert_equal [user_2], User::Search.(page: 1, per: 1).to_a
    assert_equal [user_1], User::Search.(page: 2, per: 1).to_a
  end

  test "returns paginated collection with correct metadata" do
    5.times { create :user }

    result = User::Search.(page: 2, per: 2)

    assert_equal 2, result.current_page
    assert_equal 5, result.total_count
    assert_equal 3, result.total_pages
    assert_equal 2, result.size
  end

  test "combines name and email filters" do
    user_1 = create :user, name: "Amy Smith", email: "amy@example.com"
    create :user, name: "Amy Jones", email: "amy@test.org"
    create :user, name: "Chris Smith", email: "chris@example.com"

    result = User::Search.(name: "Amy", email: "example")

    assert_equal [user_1], result.to_a
  end
end
