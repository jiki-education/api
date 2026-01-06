class User::AcquiredBadge::Reveal
  include Mandate

  initialize_with :acquired_badge

  def call
    return acquired_badge if acquired_badge.revealed?

    acquired_badge.update!(revealed: true)
    acquired_badge
  end
end
