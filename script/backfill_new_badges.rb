# Backfill first_lesson, early_bird, and beta_user badges for existing users.
#
# Run with:
#   bin/rails r script/backfill_new_badges.rb
#
# Safe to re-run: User::AcquiredBadge::Create is idempotent (returns the
# existing record if the user already has the badge) and raises
# BadgeCriteriaNotFulfilledError when award_to? is false, which we swallow.

BADGES = %w[first_lesson early_bird beta_user].freeze

stats = BADGES.index_with { { awarded: 0, skipped: 0 } }

User.find_each do |user|
  BADGES.each do |slug|
    User::AcquiredBadge::Create.(user, slug)
    stats[slug][:awarded] += 1
  rescue BadgeCriteriaNotFulfilledError
    stats[slug][:skipped] += 1
  end
end

puts "Backfill complete:"
stats.each do |slug, counts|
  puts "  #{slug.ljust(16)} awarded=#{counts[:awarded]} skipped=#{counts[:skipped]}"
end
