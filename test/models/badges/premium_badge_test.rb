require "test_helper"

class Badges::PremiumBadgeTest < ActiveSupport::TestCase
  test "has correct seed data" do
    badge = Badge.find_by_slug!('premium') # rubocop:disable Rails/DynamicFindBy

    assert_equal 'Premium', badge.name
    assert_equal 'Became a Premium member', badge.description
    refute badge.secret
  end

  test "award_to? returns true for premium users" do
    badge = Badge.find_by_slug!('premium') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.data.update!(membership_type: 'premium')

    assert badge.award_to?(user)
  end

  test "award_to? returns false for standard users" do
    badge = Badge.find_by_slug!('premium') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)

    refute badge.award_to?(user)
  end
end
