require "test_helper"

class Badges::ScenarioHandlerBadgeTest < ActiveSupport::TestCase
  test "has correct seed data" do
    badge = Badge.find_by_slug!('scenario_handler') # rubocop:disable Rails/DynamicFindBy

    assert_equal 'Scenario Handler', badge.name
    assert_equal "Solve an Exercise with Scenarios", badge.description
    refute badge.secret
  end

  test "award_to? returns true when user completed owners-bouquets lesson" do
    badge = Badge.find_by_slug!('scenario_handler') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    lesson = create(:lesson, :exercise, slug: 'owners-bouquets')
    create(:user_lesson, :completed, user:, lesson:)

    assert badge.award_to?(user)
  end

  test "award_to? returns false when user has not completed owners-bouquets lesson" do
    badge = Badge.find_by_slug!('scenario_handler') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)

    refute badge.award_to?(user)
  end

  test "award_to? returns false when user completed different lesson" do
    badge = Badge.find_by_slug!('scenario_handler') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    lesson = create(:lesson, :exercise, slug: 'different-lesson')
    create(:user_lesson, :completed, user:, lesson:)

    refute badge.award_to?(user)
  end

  test "award_to? returns false when user started but not completed owners-bouquets" do
    badge = Badge.find_by_slug!('scenario_handler') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    lesson = create(:lesson, :exercise, slug: 'owners-bouquets')
    create(:user_lesson, user:, lesson:) # Not completed

    refute badge.award_to?(user)
  end
end
