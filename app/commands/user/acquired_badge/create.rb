class User::AcquiredBadge::Create
  include Mandate

  initialize_with :user, :badge_slug

  def call
    # Return existing badge if already acquired
    acquired_badge = User::AcquiredBadge.find_by(user:, badge:)
    return acquired_badge if acquired_badge

    # Check if user meets criteria
    raise BadgeCriteriaNotFulfilledError unless badge.award_to?(user)

    # Create acquired badge with race condition handling
    User::AcquiredBadge.create_or_find!(user:, badge:)
  end

  private
  memoize
  def badge = Badge.find_by_slug!(badge_slug) # rubocop:disable Rails/DynamicFindBy
end
