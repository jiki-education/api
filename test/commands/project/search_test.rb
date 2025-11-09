require "test_helper"

class Project::SearchTest < ActiveSupport::TestCase
  test "no options returns all projects paginated and ordered by title" do
    project_1 = create :project, title: "Zebra App"
    project_2 = create :project, title: "Apple App"

    result = Project::Search.()

    assert_equal [project_2, project_1], result.to_a
  end

  test "title: search for partial title match" do
    project_1 = create :project, title: "Calculator App"
    project_2 = create :project, title: "Todo List"
    project_3 = create :project, title: "Scientific Calculator"

    assert_equal [project_1, project_3, project_2], Project::Search.(title: "").to_a
    assert_equal [project_1, project_3], Project::Search.(title: "Calculator").to_a
    assert_equal [project_2], Project::Search.(title: "Todo").to_a
    assert_empty Project::Search.(title: "xyz").to_a
  end

  test "title search is case insensitive" do
    project = create :project, title: "Calculator App"

    assert_equal [project], Project::Search.(title: "calculator").to_a
    assert_equal [project], Project::Search.(title: "CALCULATOR").to_a
    assert_equal [project], Project::Search.(title: "CaLcUlAtOr").to_a
  end

  test "pagination" do
    project_1 = create :project, title: "Apple"
    project_2 = create :project, title: "Banana"

    assert_equal [project_1], Project::Search.(page: 1, per: 1).to_a
    assert_equal [project_2], Project::Search.(page: 2, per: 1).to_a
  end

  test "returns paginated collection with correct metadata" do
    Prosopite.finish # Stop scan before creating test data
    5.times { create :project }

    Prosopite.scan # Resume scan for the actual search
    result = Project::Search.(page: 2, per: 2)

    assert_equal 2, result.current_page
    assert_equal 5, result.total_count
    assert_equal 3, result.total_pages
    assert_equal 2, result.size
  end

  test "sanitizes SQL wildcards in title search" do
    project1 = create :project, title: "100% Complete"
    create :project, title: "Todo List"
    project3 = create :project, title: "String_Parser"

    # Search for "%" should match literal "%" not act as wildcard
    result = Project::Search.(title: "%").to_a
    assert_equal [project1], result

    # Search for "_" should match literal "_" not act as single-character wildcard
    result = Project::Search.(title: "_").to_a
    assert_equal [project3], result

    # Wildcards should not match everything
    result = Project::Search.(title: "%%").to_a
    assert_empty result
  end

  test "user: orders unlocked projects first, then locked projects, all by title" do
    project_zebra = create :project, title: "Zebra Project"
    project_apple = create :project, title: "Apple Project"
    project_middle = create :project, title: "Middle Project"
    user = create :user

    # User unlocks Zebra and Middle
    create :user_project, user:, project: project_zebra
    create :user_project, user:, project: project_middle

    result = Project::Search.(user:).to_a

    # Unlocked projects first (Middle, Zebra), then locked (Apple)
    assert_equal [project_middle, project_zebra, project_apple], result
  end

  test "user: with no unlocked projects returns all projects ordered by title" do
    project_zebra = create :project, title: "Zebra Project"
    project_apple = create :project, title: "Apple Project"
    user = create :user

    result = Project::Search.(user:).to_a

    assert_equal [project_apple, project_zebra], result
  end

  test "user: with title search maintains unlocked-first ordering" do
    project_calc1 = create :project, title: "Calculator App"
    project_calc2 = create :project, title: "Scientific Calculator"
    project_calc3 = create :project, title: "Basic Calculator"
    user = create :user

    # User only unlocks Scientific Calculator
    create :user_project, user:, project: project_calc2

    result = Project::Search.(title: "Calculator", user:).to_a

    # Scientific Calculator (unlocked) first, then locked ones by title
    assert_equal [project_calc2, project_calc3, project_calc1], result
  end

  test "user: pagination works correctly with user filtering" do
    project_1 = create :project, title: "Apple"
    project_2 = create :project, title: "Banana"
    project_3 = create :project, title: "Cherry"
    user = create :user

    # User unlocks Cherry (should appear first)
    create :user_project, user:, project: project_3

    result_page1 = Project::Search.(user:, page: 1, per: 2).to_a
    result_page2 = Project::Search.(user:, page: 2, per: 2).to_a

    # First page: Cherry (unlocked), Apple (locked)
    assert_equal [project_3, project_1], result_page1
    # Second page: Banana (locked)
    assert_equal [project_2], result_page2
  end
end
