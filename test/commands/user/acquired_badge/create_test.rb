require "test_helper"

class User::AcquiredBadge::CreateTest < ActiveSupport::TestCase
  test "creates acquired badge when criteria met" do
    user = create(:user)

    acquired_badge = User::AcquiredBadge::Create.(user, 'member')

    assert acquired_badge.persisted?
    assert_equal user, acquired_badge.user
    assert_equal 'Member', acquired_badge.badge.name
    refute acquired_badge.revealed?
  end

  test "returns existing acquired badge if already acquired" do
    user = create(:user)
    existing = User::AcquiredBadge::Create.(user, 'member')

    result = User::AcquiredBadge::Create.(user, 'member')

    assert_equal existing.id, result.id
    assert_equal 1, User::AcquiredBadge.count
  end

  test "raises error when criteria not met" do
    user = create(:user)

    assert_raises BadgeCriteriaNotFulfilledError do
      User::AcquiredBadge::Create.(user, 'maze_navigator')
    end
  end

  test "handles race condition when creating duplicate" do
    user = create(:user)
    badge = Badge.find_by_slug!('member') # rubocop:disable Rails/DynamicFindBy

    # Simulate race condition: badge created between check and create
    User::AcquiredBadge.create!(user:, badge:)

    # Should return existing instead of raising error
    result = User::AcquiredBadge::Create.(user, 'member')

    assert_equal user, result.user
    assert_equal badge, result.badge
    assert_equal 1, User::AcquiredBadge.count
  end

  test "increments badge num_awardees counter" do
    user = create(:user)
    badge = Badge.find_by_slug!('member') # rubocop:disable Rails/DynamicFindBy

    assert_equal 0, badge.num_awardees

    User::AcquiredBadge::Create.(user, 'member')

    assert_equal 1, badge.reload.num_awardees
  end

  test "creates badge on-demand if it doesn't exist" do
    user = create(:user)

    assert_equal 0, Badge.count

    User::AcquiredBadge::Create.(user, 'member')

    assert_equal 1, Badge.count
    assert Badge.exists?(type: 'Badges::MemberBadge')
  end
end
