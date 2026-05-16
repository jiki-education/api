require "test_helper"

class Badges::SidekickBadgeTest < ActiveSupport::TestCase
  test "has correct seed data" do
    badge = Badge.find_by_slug!('sidekick') # rubocop:disable Rails/DynamicFindBy

    assert_equal 'Sidekick', badge.name
    assert_equal 'Sent your first message to Jiki', badge.description
    refute badge.secret
  end

  test "award_to? returns true when user has sent a message" do
    badge = Badge.find_by_slug!('sidekick') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    lesson = create(:lesson, :exercise)
    create(:assistant_conversation, user:, context: lesson,
      messages: [{ role: "user", content: "hi", timestamp: "2026-01-01T00:00:00Z" }])

    assert badge.award_to?(user)
  end

  test "award_to? returns false when user has no conversations" do
    badge = Badge.find_by_slug!('sidekick') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)

    refute badge.award_to?(user)
  end

  test "award_to? returns false when only assistant messages exist" do
    badge = Badge.find_by_slug!('sidekick') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    lesson = create(:lesson, :exercise)
    create(:assistant_conversation, user:, context: lesson,
      messages: [{ role: "assistant", content: "hello", timestamp: "2026-01-01T00:00:00Z" }])

    refute badge.award_to?(user)
  end
end
