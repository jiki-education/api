require "test_helper"

class SerializeBadgesTest < ActiveSupport::TestCase
  test "returns all non-secret badges" do
    user = create(:user)
    create(:test_public_3_badge)
    create(:test_public_4_badge)
    create(:test_secret_1_badge)

    result = SerializeBadges.(user)

    badge_names = result.map { |b| b[:name] }
    assert_includes badge_names, "Badge 1"
    assert_includes badge_names, "Badge 2"
    refute_includes badge_names, "Secret Badge"
  end

  test "includes acquired secret badges" do
    user = create(:user)
    secret_badge = create(:test_secret_1_badge)
    create(:user_acquired_badge, user:, badge: secret_badge)

    result = SerializeBadges.(user)

    badge_names = result.map { |b| b[:name] }
    assert_includes badge_names, "Secret Badge"
  end

  test "excludes non-acquired secret badges" do
    user = create(:user)
    create(:test_secret_2_badge)
    secret_badge2 = create(:test_secret_3_badge)
    create(:user_acquired_badge, user:, badge: secret_badge2)

    result = SerializeBadges.(user)

    badge_names = result.map { |b| b[:name] }
    refute_includes badge_names, "Secret Badge 1"
    assert_includes badge_names, "Secret Badge 2"
  end

  test "sets state to locked for non-acquired badges" do
    user = create(:user)
    create(:member_badge)

    result = SerializeBadges.(user)

    locked_badge = result.find { |b| b[:name] == "Member" }
    assert_equal "locked", locked_badge[:state]
    assert_nil locked_badge[:unlocked_at]
  end

  test "sets state to unrevealed for acquired but not revealed badges" do
    user = create(:user)
    badge = create(:test_public_1_badge)
    acquired = create(:user_acquired_badge, user:, badge:, revealed: false)

    result = SerializeBadges.(user)

    unrevealed_badge = result.find { |b| b[:name] == "Public Badge 1" }
    assert_equal "unrevealed", unrevealed_badge[:state]
    assert_equal acquired.created_at.iso8601, unrevealed_badge[:unlocked_at]
  end

  test "sets state to revealed for revealed badges" do
    user = create(:user)
    badge = create(:test_public_2_badge)
    acquired = create(:user_acquired_badge, :revealed, user:, badge:)

    result = SerializeBadges.(user)

    revealed_badge = result.find { |b| b[:name] == "Public Badge 2" }
    assert_equal "revealed", revealed_badge[:state]
    assert_equal acquired.created_at.iso8601, revealed_badge[:unlocked_at]
  end

  test "includes badge details in serialized output" do
    user = create(:user)
    badge = create(:test_public_1_badge)

    result = SerializeBadges.(user)

    serialized_badge = result.find { |b| b[:name] == "Public Badge 1" }
    assert_equal badge.id, serialized_badge[:id]
    assert_equal "star", serialized_badge[:icon]
    assert_equal "Test public badge 1", serialized_badge[:description]
  end

  test "orders badges by id" do
    user = create(:user)
    badge3 = create(:maze_navigator_badge)
    badge1 = create(:test_public_3_badge)
    badge2 = create(:test_public_4_badge)

    result = SerializeBadges.(user)

    ids = result.map { |b| b[:id] }
    assert_equal [badge1.id, badge2.id, badge3.id].sort, ids
  end
end
