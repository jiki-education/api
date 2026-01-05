require "test_helper"

class BadgeTest < ActiveSupport::TestCase
  test "find_by_slug! creates badge on first access" do
    assert_equal 0, Badge.count

    badge = Badge.find_by_slug!('member') # rubocop:disable Rails/DynamicFindBy

    assert_equal 1, Badge.count
    assert_equal 'Member', badge.name
    assert_equal 'logo', badge.icon
    assert_equal 'Joined Jiki', badge.description
    refute badge.secret
    assert_instance_of Badges::MemberBadge, badge
  end

  test "find_by_slug! returns existing badge on subsequent access" do
    badge1 = Badge.find_by_slug!('member') # rubocop:disable Rails/DynamicFindBy
    badge2 = Badge.find_by_slug!('member') # rubocop:disable Rails/DynamicFindBy

    assert_equal badge1.id, badge2.id
    assert_equal 1, Badge.count
  end

  test "find_by_slug! handles race condition" do
    # Simulate race condition by creating badge directly
    Badges::MemberBadge.create!

    # Should return existing badge instead of raising error
    badge = Badge.find_by_slug!('member') # rubocop:disable Rails/DynamicFindBy

    assert_instance_of Badges::MemberBadge, badge
    assert_equal 1, Badge.count
  end

  test "percentage_awardees returns 0 when no awardees" do
    badge = create(:badge)

    assert_equal 0, badge.percentage_awardees
  end

  test "percentage_awardees calculates correct percentage" do
    badge = create(:badge, num_awardees: 25)
    create_list(:user, 100)

    assert_equal 25.0, badge.percentage_awardees
  end

  test "percentage_awardees returns 0 when no users" do
    badge = create(:badge, num_awardees: 5)

    assert_equal 0, badge.percentage_awardees
  end

  test "award_to? must be implemented by subclasses" do
    # Create a badge instance directly (bypassing factory) to test the base class
    badge = Badge.new(name: "Test", icon: "test", description: "test", type: "Badge")
    user = create(:user)

    assert_raises NotImplementedError do
      badge.award_to?(user)
    end
  end
end
