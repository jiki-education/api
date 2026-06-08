require "test_helper"

class Badges::BetaUserBadgeTest < ActiveSupport::TestCase
  test "has correct seed data" do
    badge = Badge.find_by_slug!('beta_user') # rubocop:disable Rails/DynamicFindBy

    assert_equal 'Beta User', badge.name
    assert_equal 'Joined Jiki during the beta', badge.description
    assert badge.secret
  end

  test "award_to? returns true when user was created before July 1st 2026" do
    badge = Badge.find_by_slug!('beta_user') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.update_column(:created_at, Time.utc(2026, 6, 30, 23, 59, 59))

    assert badge.award_to?(user)
  end

  test "award_to? returns false when user was created on July 1st 2026" do
    badge = Badge.find_by_slug!('beta_user') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.update_column(:created_at, Time.utc(2026, 7, 1, 0, 0, 0))

    refute badge.award_to?(user)
  end

  test "award_to? returns false when user was created after July 1st 2026" do
    badge = Badge.find_by_slug!('beta_user') # rubocop:disable Rails/DynamicFindBy
    user = create(:user)
    user.update_column(:created_at, Time.utc(2026, 8, 1, 0, 0, 0))

    refute badge.award_to?(user)
  end
end
