require "test_helper"

class User::AcquiredBadgeTest < ActiveSupport::TestCase
  test "belongs to user" do
    user = create(:user)
    badge = create(:badge)
    acquired_badge = create(:user_acquired_badge, user:, badge:)

    assert_equal user, acquired_badge.user
  end

  test "belongs to badge" do
    user = create(:user)
    badge = create(:badge)
    acquired_badge = create(:user_acquired_badge, user:, badge:)

    assert_equal badge, acquired_badge.badge
  end

  test "counter cache increments badge num_awardees on create" do
    user = create(:user)
    badge = create(:member_badge)
    initial_count = badge.num_awardees

    create(:user_acquired_badge, user:, badge:)

    assert_equal initial_count + 1, badge.reload.num_awardees
  end

  test "counter cache decrements badge num_awardees on destroy" do
    user = create(:user)
    badge = create(:test_public_1_badge)
    acquired_badge = create(:user_acquired_badge, user:, badge:)
    count_before_destroy = badge.reload.num_awardees

    acquired_badge.destroy

    assert_equal count_before_destroy - 1, badge.reload.num_awardees
  end

  test "enforces uniqueness of user_id and badge_id combination" do
    user = create(:user)
    badge = create(:badge)
    create(:user_acquired_badge, user:, badge:)

    assert_raises ActiveRecord::RecordNotUnique do
      create(:user_acquired_badge, user:, badge:)
    end
  end

  test "allows same badge for different users" do
    user1 = create(:user)
    user2 = create(:user)
    badge = create(:badge)

    acquired1 = create(:user_acquired_badge, user: user1, badge:)
    acquired2 = create(:user_acquired_badge, user: user2, badge:)

    refute_equal acquired1.id, acquired2.id
  end

  test "allows different badges for same user" do
    user = create(:user)
    badge1 = create(:member_badge)
    badge2 = create(:maze_navigator_badge)

    acquired1 = create(:user_acquired_badge, user:, badge: badge1)
    acquired2 = create(:user_acquired_badge, user:, badge: badge2)

    refute_equal acquired1.id, acquired2.id
  end

  test "unrevealed scope returns only unrevealed badges" do
    user = create(:user)
    badge1 = create(:test_public_1_badge)
    badge2 = create(:test_public_2_badge)
    unrevealed = create(:user_acquired_badge, user:, badge: badge1, revealed: false)
    create(:user_acquired_badge, :revealed, user:, badge: badge2)

    assert_equal [unrevealed], user.acquired_badges.unrevealed.to_a
  end

  test "revealed scope returns only revealed badges" do
    user = create(:user)
    badge1 = create(:test_public_3_badge)
    badge2 = create(:test_public_4_badge)
    create(:user_acquired_badge, user:, badge: badge1, revealed: false)
    revealed = create(:user_acquired_badge, :revealed, user:, badge: badge2)

    assert_equal [revealed], user.acquired_badges.revealed.to_a
  end

  test "delegates name to badge" do
    badge = create(:test_public_1_badge)
    acquired_badge = create(:user_acquired_badge, badge:)

    assert_equal "Public Badge 1", acquired_badge.name
  end

  test "delegates icon to badge" do
    badge = create(:test_public_1_badge)
    acquired_badge = create(:user_acquired_badge, badge:)

    assert_equal "star", acquired_badge.icon
  end

  test "delegates description to badge" do
    badge = create(:test_public_1_badge)
    acquired_badge = create(:user_acquired_badge, badge:)

    assert_equal "Test public badge 1", acquired_badge.description
  end

  test "delegates secret to badge" do
    badge = create(:test_secret_1_badge)
    acquired_badge = create(:user_acquired_badge, badge:)

    assert acquired_badge.secret
  end
end
