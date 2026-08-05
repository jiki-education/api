require "test_helper"

class Badges::TownsfolkBadgeTest < ActiveSupport::TestCase
  test "has correct seed data" do
    badge = Badge.find_by_slug!('townsfolk') # rubocop:disable Rails/DynamicFindBy

    assert_equal 'townsfolk', badge.slug
    refute badge.secret
  end

  test "award_to? returns true for any user" do
    badge = Badge.find_by_slug!('townsfolk') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)

    assert badge.award_to?(user)
  end
end
