require "test_helper"

class SerializeBadgesTest < ActiveSupport::TestCase
  test "returns all non-secret badges" do
    user = create(:user)
    create(:member_badge)
    create(:maze_navigator_badge)
    create(:early_bird_badge)

    result = SerializeBadges.(user)

    slugs = result.map { |b| b[:slug] }
    assert_includes slugs, "member"
    assert_includes slugs, "maze_navigator"
    refute_includes slugs, "early_bird"
  end

  test "includes acquired secret badges" do
    user = create(:user)
    secret_badge = create(:early_bird_badge)
    create(:user_acquired_badge, user:, badge: secret_badge)

    result = SerializeBadges.(user)

    assert_includes result.map { |b| b[:slug] }, "early_bird"
  end

  test "excludes non-acquired secret badges" do
    user = create(:user)
    create(:early_bird_badge)

    result = SerializeBadges.(user)

    refute_includes result.map { |b| b[:slug] }, "early_bird"
  end

  test "sets state to locked for non-acquired badges" do
    user = create(:user)
    create(:member_badge)

    result = SerializeBadges.(user)

    locked_badge = result.find { |b| b[:slug] == "member" }
    assert_equal "locked", locked_badge[:state]
    assert_nil locked_badge[:unlocked_at]
  end

  test "sets state to unrevealed for acquired but not revealed badges" do
    user = create(:user)
    badge = create(:member_badge)
    acquired = create(:user_acquired_badge, user:, badge:, revealed: false)

    result = SerializeBadges.(user)

    unrevealed_badge = result.find { |b| b[:slug] == "member" }
    assert_equal "unrevealed", unrevealed_badge[:state]
    assert_equal acquired.created_at.iso8601, unrevealed_badge[:unlocked_at]
  end

  test "sets state to revealed for revealed badges" do
    user = create(:user)
    badge = create(:maze_navigator_badge)
    acquired = create(:user_acquired_badge, :revealed, user:, badge:)

    result = SerializeBadges.(user)

    revealed_badge = result.find { |b| b[:slug] == "maze_navigator" }
    assert_equal "revealed", revealed_badge[:state]
    assert_equal acquired.created_at.iso8601, revealed_badge[:unlocked_at]
  end

  test "includes badge details in serialized output" do
    user = create(:user)
    badge = create(:member_badge)

    result = SerializeBadges.(user)

    serialized_badge = result.find { |b| b[:slug] == "member" }
    assert_equal badge.id, serialized_badge[:id]
    assert_equal 0, serialized_badge[:num_awardees]
  end

  # Names, descriptions and fun facts are authored in the front-end curriculum
  # repo (curriculum/src/badges/locales/), keyed by slug.
  test "does not include name, description or fun_fact" do
    user = create(:user)
    create(:member_badge)

    serialized_badge = SerializeBadges.(user).first

    refute serialized_badge.key?(:name)
    refute serialized_badge.key?(:description)
    refute serialized_badge.key?(:fun_fact)
  end

  test "orders badges by id" do
    user = create(:user)
    badge1 = create(:member_badge)
    badge2 = create(:maze_navigator_badge)
    badge3 = create(:early_bird_badge)
    create(:user_acquired_badge, user:, badge: badge3) # Acquire secret badge so it's included

    result = SerializeBadges.(user)

    ids = result.map { |b| b[:id] }
    assert_equal [badge1.id, badge2.id, badge3.id].sort, ids
  end
end
