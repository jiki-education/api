require "test_helper"

class Level::SearchTest < ActiveSupport::TestCase
  test "no options returns all levels paginated" do
    level_1 = create :level
    level_2 = create :level, slug: "level-2"

    result = Level::Search.()

    assert_equal [level_1, level_2], result.to_a
  end

  test "title: search for partial title match" do
    level_1 = create :level, title: "Introduction to Ruby"
    level_2 = create :level, title: "Advanced Ruby"
    level_3 = create :level, title: "Introduction to Python"

    assert_equal [level_1, level_2, level_3].sort_by(&:id), Level::Search.(title: "").to_a.sort_by(&:id)
    assert_equal [level_1, level_3].sort_by(&:id), Level::Search.(title: "Introduction").to_a.sort_by(&:id)
    assert_equal [level_1, level_2].sort_by(&:id), Level::Search.(title: "Ruby").to_a.sort_by(&:id)
    assert_empty Level::Search.(title: "xyz").to_a
  end

  test "slug: search for partial slug match" do
    level_1 = create :level, slug: "ruby-basics"
    level_2 = create :level, slug: "ruby-advanced"
    level_3 = create :level, slug: "python-basics"

    assert_equal [level_1, level_2, level_3].sort_by(&:id), Level::Search.(slug: "").to_a.sort_by(&:id)
    assert_equal [level_1, level_2].sort_by(&:id), Level::Search.(slug: "ruby").to_a.sort_by(&:id)
    assert_equal [level_1, level_3].sort_by(&:id), Level::Search.(slug: "basics").to_a.sort_by(&:id)
    assert_empty Level::Search.(slug: "xyz").to_a
  end

  test "pagination" do
    level_1 = create :level
    level_2 = create :level, slug: "level-2"

    assert_equal [level_1], Level::Search.(page: 1, per: 1).to_a
    assert_equal [level_2], Level::Search.(page: 2, per: 1).to_a
  end

  test "returns paginated collection with correct metadata" do
    Prosopite.finish
    5.times { |i| create :level, slug: "level-#{i}" }
    Prosopite.scan

    result = Level::Search.(page: 2, per: 2)

    assert_equal 2, result.current_page
    assert_equal 5, result.total_count
    assert_equal 3, result.total_pages
    assert_equal 2, result.size
  end

  test "combines multiple filters" do
    level_1 = create :level, title: "Ruby Basics", slug: "ruby-basics"
    create :level, title: "Ruby Advanced", slug: "ruby-advanced"
    create :level, title: "Python Basics", slug: "python-basics"

    result = Level::Search.(title: "Ruby", slug: "basics")

    assert_equal [level_1], result.to_a
  end
end
