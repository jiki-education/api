require "test_helper"

class Badges::MazeNavigatorBadgeTest < ActiveSupport::TestCase
  test "has correct seed data" do
    badge = Badge.find_by_slug!('maze_navigator') # rubocop:disable Rails/DynamicFindBy

    assert_equal 'Maze Navigator', badge.name
    assert_equal 'compass', badge.icon
    assert_equal 'Completed the Solve a Maze lesson', badge.description
    refute badge.secret
  end

  test "award_to? returns true when user completed maze-solve-basic lesson" do
    badge = Badge.find_by_slug!('maze_navigator') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    lesson = create(:lesson, slug: 'maze-solve-basic')
    create(:user_lesson, :completed, user:, lesson:)

    assert badge.award_to?(user)
  end

  test "award_to? returns false when user has not completed maze-solve-basic lesson" do
    badge = Badge.find_by_slug!('maze_navigator') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)

    refute badge.award_to?(user)
  end

  test "award_to? returns false when user completed different lesson" do
    badge = Badge.find_by_slug!('maze_navigator') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    lesson = create(:lesson, slug: 'different-lesson')
    create(:user_lesson, :completed, user:, lesson:)

    refute badge.award_to?(user)
  end

  test "award_to? returns false when user started but not completed maze-solve-basic" do
    badge = Badge.find_by_slug!('maze_navigator') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    lesson = create(:lesson, slug: 'maze-solve-basic')
    create(:user_lesson, user:, lesson:) # Not completed

    refute badge.award_to?(user)
  end
end
