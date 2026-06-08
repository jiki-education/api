require "test_helper"

class Badges::FirstLessonBadgeTest < ActiveSupport::TestCase
  test "has correct seed data" do
    badge = Badge.find_by_slug!('first_lesson') # rubocop:disable Rails/DynamicFindBy

    assert_equal 'First Steps', badge.name
    assert_equal 'Completed your first lesson', badge.description
    refute badge.secret
  end

  test "award_to? returns true when user has a completed lesson" do
    badge = Badge.find_by_slug!('first_lesson') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    lesson = create(:lesson, :exercise)
    create(:user_lesson, :completed, user:, lesson:)

    assert badge.award_to?(user)
  end

  test "award_to? returns false when user has no completed lessons" do
    badge = Badge.find_by_slug!('first_lesson') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)

    refute badge.award_to?(user)
  end

  test "award_to? returns false when user has an in-progress lesson but none completed" do
    badge = Badge.find_by_slug!('first_lesson') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    lesson = create(:lesson, :exercise)
    create(:user_lesson, user:, lesson:)

    refute badge.award_to?(user)
  end
end
