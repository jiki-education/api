require "test_helper"

class Badges::TownsfolkBadgeTest < ActiveSupport::TestCase
  test "has correct seed data" do
    badge = Badge.find_by_slug!('townsfolk') # rubocop:disable Rails/DynamicFindBy

    assert_equal 'Townsfolk', badge.name
    assert_equal 'Joined the Jiki community forum', badge.description
    refute badge.secret
  end

  test "award_to? returns true for any user" do
    badge = Badge.find_by_slug!('townsfolk') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)

    assert badge.award_to?(user)
  end
end
