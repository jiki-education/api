require "test_helper"

class Badges::EarlyBirdBadgeTest < ActiveSupport::TestCase
  test "has correct seed data" do
    badge = Badge.find_by_slug!('early_bird') # rubocop:disable Rails/DynamicFindBy

    assert_equal 'Early Bird', badge.name
    assert_equal 'Completed a lesson in the early-morning hours', badge.description
    assert badge.secret
  end

  test "award_to? returns true when lesson completed at 5am in user timezone" do
    badge = Badge.find_by_slug!('early_bird') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.data.update!(timezone: "UTC")
    lesson = create(:lesson, :exercise)
    create(:user_lesson, :completed, user:, lesson:, completed_at: Time.utc(2026, 3, 21, 5, 0, 0))

    assert badge.award_to?(user)
  end

  test "award_to? returns true at boundary of exactly 4am" do
    badge = Badge.find_by_slug!('early_bird') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.data.update!(timezone: "UTC")
    lesson = create(:lesson, :exercise)
    create(:user_lesson, :completed, user:, lesson:, completed_at: Time.utc(2026, 3, 21, 4, 0, 0))

    assert badge.award_to?(user)
  end

  test "award_to? returns false at boundary of exactly 9am" do
    badge = Badge.find_by_slug!('early_bird') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.data.update!(timezone: "UTC")
    lesson = create(:lesson, :exercise)
    create(:user_lesson, :completed, user:, lesson:, completed_at: Time.utc(2026, 3, 21, 9, 0, 0))

    refute badge.award_to?(user)
  end

  test "award_to? returns false at 3:59am" do
    badge = Badge.find_by_slug!('early_bird') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.data.update!(timezone: "UTC")
    lesson = create(:lesson, :exercise)
    create(:user_lesson, :completed, user:, lesson:, completed_at: Time.utc(2026, 3, 21, 3, 59, 0))

    refute badge.award_to?(user)
  end

  test "award_to? returns false when lesson completed at 3pm" do
    badge = Badge.find_by_slug!('early_bird') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.data.update!(timezone: "UTC")
    lesson = create(:lesson, :exercise)
    create(:user_lesson, :completed, user:, lesson:, completed_at: Time.utc(2026, 3, 21, 15, 0, 0))

    refute badge.award_to?(user)
  end

  test "award_to? returns false when no completed lessons" do
    badge = Badge.find_by_slug!('early_bird') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)

    refute badge.award_to?(user)
  end

  test "award_to? respects user timezone" do
    badge = Badge.find_by_slug!('early_bird') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.data.update!(timezone: "Asia/Karachi") # UTC+5
    lesson = create(:lesson, :exercise)
    # 5am UTC = 10am in Asia/Karachi - outside window
    create(:user_lesson, :completed, user:, lesson:, completed_at: Time.utc(2026, 3, 21, 5, 0, 0))

    refute badge.award_to?(user)
  end

  test "award_to? converts UTC to early morning in user timezone" do
    badge = Badge.find_by_slug!('early_bird') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.data.update!(timezone: "Asia/Karachi") # UTC+5
    lesson = create(:lesson, :exercise)
    # midnight UTC = 5am in Asia/Karachi - in window
    create(:user_lesson, :completed, user:, lesson:, completed_at: Time.utc(2026, 3, 21, 0, 0, 0))

    assert badge.award_to?(user)
  end
end
