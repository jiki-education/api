# Development-only sample data: a test user with progress, demo badge states and
# fake payments. Loaded by db/seeds.rb - NEVER load this in production.

raise "Development seeds must only run in development!" unless Rails.env.development?

course = Course.find_by!(slug: "coding-fundamentals")
admin_user = User.find_by!(email: "ihid@jiki.io")

# == Test user ==
user = User.find_or_create_by!(email: "test@example.com") do |u|
  u.handle = "testuser"
  u.name = "Test User"
  u.password = "password123"
end
user.confirm unless user.confirmed?
UserCourse::Enroll.(user, course)
puts "✓ Test user: #{user.email}"

# == Sample progress for the test user ==
# First level: 2 lessons completed, 1 started. Second level: 2 lessons started.
first_level = course.levels.first
second_level = course.levels.second
raise "Cannot create sample progress: course has fewer than 2 levels" unless first_level && second_level

user_course = UserCourse.find_by!(user:, course:)
UserLevel.find_or_create_by!(user:, level: first_level)
user_level_2 = UserLevel.find_or_create_by!(user:, level: second_level)
user_course.update!(current_user_level: user_level_2)

first_level.lessons.limit(3).each_with_index do |lesson, index|
  UserLesson.find_or_create_by!(user:, lesson:) do |ul|
    ul.completed_at = index < 2 ? Time.current : nil
  end
end

second_level.lessons.limit(2).each do |lesson|
  UserLesson.find_or_create_by!(user:, lesson:)
end
puts "✓ Sample progress for #{user.email}"

# == Demo badge acquisitions for the admin user ==
# Covers all badge states: locked (Maze Navigator - no record), new/unrevealed
# (Member, First Lesson) and seen/revealed (Early Bird).
User::AcquiredBadge.find_or_create_by!(user: admin_user, badge: Badges::MemberBadge.first) do |ab|
  ab.revealed = false
  ab.created_at = 1.day.ago
end
User::AcquiredBadge.find_or_create_by!(user: admin_user, badge: Badges::FirstLessonBadge.first) do |ab|
  ab.revealed = false
  ab.created_at = 1.hour.ago
end
User::AcquiredBadge.find_or_create_by!(user: admin_user, badge: Badges::EarlyBirdBadge.first) do |ab|
  ab.revealed = true
  ab.created_at = 3.days.ago
end
puts "✓ Demo badges for #{admin_user.email}"

# == Fake payments for the admin user ==
# The test user deliberately has none (for testing the no-payments state).
[
  { months_ago: 4, product: "premium", amount: 1999 },
  { months_ago: 3, product: "premium", amount: 1999 },
  { months_ago: 2, product: "premium", amount: 1999 },
  { months_ago: 1, product: "premium", amount: 1999 }
].each_with_index do |payment_data, index|
  payment_date = payment_data[:months_ago].months.ago
  Payment.find_or_create_by!(payment_processor_id: "in_seed_#{index + 1}") do |p|
    p.user = admin_user
    p.amount_in_cents = payment_data[:amount]
    p.currency = "usd"
    p.product = payment_data[:product]
    p.external_receipt_url = "https://invoice.stripe.com/i/seed_receipt_#{index + 1}"
    p.data = {
      stripe_invoice_id: "in_seed_#{index + 1}",
      stripe_charge_id: "ch_seed_#{index + 1}",
      stripe_subscription_id: "sub_seed_admin",
      stripe_customer_id: "cus_seed_admin",
      billing_reason: index.zero? ? "subscription_create" : "subscription_cycle",
      period_start: payment_date.iso8601,
      period_end: (payment_date + 1.month).iso8601
    }
    p.created_at = payment_date
  end
end
puts "✓ Sample payments for #{admin_user.email}"
