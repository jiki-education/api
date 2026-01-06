require "test_helper"

class Badges::MemberBadgeTest < ActiveSupport::TestCase
  test "has correct seed data" do
    badge = Badge.find_by_slug!('member') # rubocop:disable Rails/DynamicFindBy

    assert_equal 'Member', badge.name
    assert_equal 'logo', badge.icon
    assert_equal 'Joined Jiki', badge.description
    refute badge.secret
  end

  test "award_to? always returns true" do
    badge = Badge.find_by_slug!('member') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)

    assert badge.award_to?(user)
  end

  test "award_to? returns true for any user" do
    badge = Badge.find_by_slug!('member') # rubocop:disable Rails/DynamicFindBy
    user1 = create(:user)
    user2 = create(:user)

    assert badge.award_to?(user1)
    assert badge.award_to?(user2)
  end
end
