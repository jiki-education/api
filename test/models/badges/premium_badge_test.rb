require "test_helper"

class Badges::PremiumBadgeTest < ActiveSupport::TestCase
  test "has correct seed data" do
    badge = Badge.find_by_slug!('premium') # rubocop:disable Rails/DynamicFindBy

    assert_equal 'Premium', badge.name
    assert_equal 'Became a Premium member', badge.description
    refute badge.secret
  end

  test "award_to? returns true for premium users via Stripe" do
    badge = Badge.find_by_slug!('premium') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.data.update!(subscription_status: "active")

    assert badge.award_to?(user)
  end

  test "award_to? returns true for premium users via an entitlement" do
    badge = Badge.find_by_slug!('premium') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    create(:premium_entitlement, :insider, user:)

    assert badge.award_to?(user)
  end

  test "award_to? returns false for standard users" do
    badge = Badge.find_by_slug!('premium') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)

    refute badge.award_to?(user)
  end
end
