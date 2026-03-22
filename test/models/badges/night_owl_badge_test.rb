require "test_helper"

class Badges::NightOwlBadgeTest < ActiveSupport::TestCase
  test "has correct seed data" do
    badge = Badge.find_by_slug!('night_owl') # rubocop:disable Rails/DynamicFindBy

    assert_equal 'Night Owl', badge.name
    assert_equal 'Completed a lesson in the late-night hours', badge.description
    assert badge.secret
  end

  test "award_to? returns true when lesson completed at 10pm in user timezone" do
    badge = Badge.find_by_slug!('night_owl') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.data.update!(timezone: "UTC")
    lesson = create(:lesson, :exercise)
    create(:user_lesson, :completed, user:, lesson:, completed_at: Time.utc(2026, 3, 21, 22, 0, 0))

    assert badge.award_to?(user)
  end

  test "award_to? returns true when lesson completed at 1am in user timezone" do
    badge = Badge.find_by_slug!('night_owl') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.data.update!(timezone: "UTC")
    lesson = create(:lesson, :exercise)
    create(:user_lesson, :completed, user:, lesson:, completed_at: Time.utc(2026, 3, 21, 1, 0, 0))

    assert badge.award_to?(user)
  end

  test "award_to? returns true at boundary of exactly 9pm" do
    badge = Badge.find_by_slug!('night_owl') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.data.update!(timezone: "UTC")
    lesson = create(:lesson, :exercise)
    create(:user_lesson, :completed, user:, lesson:, completed_at: Time.utc(2026, 3, 21, 21, 0, 0))

    assert badge.award_to?(user)
  end

  test "award_to? returns true at boundary of exactly 2:30am" do
    badge = Badge.find_by_slug!('night_owl') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.data.update!(timezone: "UTC")
    lesson = create(:lesson, :exercise)
    create(:user_lesson, :completed, user:, lesson:, completed_at: Time.utc(2026, 3, 21, 2, 30, 0))

    assert badge.award_to?(user)
  end

  test "award_to? returns false when lesson completed at 3pm" do
    badge = Badge.find_by_slug!('night_owl') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.data.update!(timezone: "UTC")
    lesson = create(:lesson, :exercise)
    create(:user_lesson, :completed, user:, lesson:, completed_at: Time.utc(2026, 3, 21, 15, 0, 0))

    refute badge.award_to?(user)
  end

  test "award_to? returns false at boundary of 2:31am" do
    badge = Badge.find_by_slug!('night_owl') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.data.update!(timezone: "UTC")
    lesson = create(:lesson, :exercise)
    create(:user_lesson, :completed, user:, lesson:, completed_at: Time.utc(2026, 3, 21, 2, 31, 0))

    refute badge.award_to?(user)
  end

  test "award_to? returns false when no completed lessons" do
    badge = Badge.find_by_slug!('night_owl') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)

    refute badge.award_to?(user)
  end

  test "award_to? respects user timezone" do
    badge = Badge.find_by_slug!('night_owl') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.data.update!(timezone: "Asia/Karachi") # UTC+5
    lesson = create(:lesson, :exercise)
    # 10pm UTC = 3am in Asia/Karachi (UTC+5) - 3am is outside the 9pm-2:30am window
    create(:user_lesson, :completed, user:, lesson:, completed_at: Time.utc(2026, 3, 21, 22, 0, 0))

    refute badge.award_to?(user)
  end

  test "award_to? converts daytime UTC to night in user timezone" do
    badge = Badge.find_by_slug!('night_owl') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.data.update!(timezone: "Asia/Karachi") # UTC+5
    lesson = create(:lesson, :exercise)
    # 4pm UTC = 9pm in Asia/Karachi (UTC+5) - should be true
    create(:user_lesson, :completed, user:, lesson:, completed_at: Time.utc(2026, 3, 21, 16, 0, 0))

    assert badge.award_to?(user)
  end
end
