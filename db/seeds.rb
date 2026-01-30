# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create an admin user
admin_user = User.find_or_create_by!(email: "ihid@jiki.io") do |u|
  u.admin = true
  u.handle = "iHiD"
  u.name = "Jeremy Walker"
  u.password = "password"
  u.password_confirmation = "password"
end
admin_user.confirm
puts "Created admin user: #{admin_user.email}"

# Create a test user
user = User.find_or_create_by!(email: "test@example.com") do |u|
  u.handle = "testuser"
  u.name = "Test User"
  u.password = "password123"
  u.password_confirmation = "password123"
end
puts "Created user: #{user.email}"

# Create the Coding Fundamentals course
course = Course.find_or_create_by!(slug: "coding-fundamentals") do |c|
  c.title = "Coding Fundamentals"
  c.description = "Learn the fundamentals of programming through interactive exercises and videos."
end
puts "Created course: #{course.title}"

# Bootstrap levels from curriculum.json
curriculum_file = File.join(Rails.root, "db", "seeds", "curriculum.json")
puts "Loading levels from #{curriculum_file}..."

Level::CreateAllFromJson.call(course, curriculum_file, delete_existing: false)

puts "✓ Successfully loaded levels and lessons!"

# Bootstrap users (enrolls them in coding-fundamentals and starts first level)
puts "\nBootstrapping users..."
User::Bootstrap.(admin_user)
puts "  ✓ Bootstrapped admin user"
User::Bootstrap.(user)
puts "  ✓ Bootstrapped test user"

# Load concepts
puts "\nLoading concepts..."
concepts_file = File.join(Rails.root, "db", "seeds", "concepts.json")
if File.exist?(concepts_file)
  concepts_data = JSON.parse(File.read(concepts_file), symbolize_names: true)

  # First pass: Create all concepts without parents
  concepts_data.each do |concept_data|
    concept = Concept.find_or_initialize_by(slug: concept_data[:slug])
    concept.title = concept_data[:title]
    concept.description = concept_data[:description]
    concept.content_markdown = concept_data[:content_markdown]

    # Link to lesson if specified
    if concept_data[:unlocked_by_lesson_slug]
      lesson = Lesson.find_by(slug: concept_data[:unlocked_by_lesson_slug])
      concept.unlocked_by_lesson = lesson if lesson
    end

    concept.save!
    puts "  ✓ Loaded concept: #{concept.title}"
  end

  # Second pass: Link parents (iterative until all resolved)
  unresolved = concepts_data.select { |c| c[:parent_slug].present? }
  while unresolved.any?
    resolved_count = 0
    unresolved.each do |concept_data|
      parent = Concept.find_by(slug: concept_data[:parent_slug])
      next unless parent

      concept = Concept.find_by!(slug: concept_data[:slug])
      next if concept.parent_concept_id.present?

      concept.update!(parent: parent)
      resolved_count += 1
      puts "  ✓ Linked #{concept.title} → #{parent.title}"
    end

    unresolved.reject! { |c| Concept.find_by(slug: c[:slug])&.parent_concept_id.present? }
    break if resolved_count.zero? && unresolved.any?
  end

  # Warn about any unresolved
  unresolved.each do |c|
    puts "  ⚠ Could not resolve parent '#{c[:parent_slug]}' for concept '#{c[:slug]}'"
  end

  puts "✓ Successfully loaded #{concepts_data.size} concept(s)!"
else
  puts "⚠ No concepts.json found at #{concepts_file}"
end

# Load projects
puts "\nLoading projects..."
projects_file = File.join(Rails.root, "db", "seeds", "projects.json")
if File.exist?(projects_file)
  projects_data = JSON.parse(File.read(projects_file), symbolize_names: true)

  projects_data.each do |project_data|
    project = Project.find_or_initialize_by(slug: project_data[:slug])
    project.title = project_data[:title]
    project.description = project_data[:description]
    project.exercise_slug = project_data[:exercise_slug]

    # Link to lesson if specified
    if project_data[:unlocked_by_lesson_slug]
      lesson = Lesson.find_by(slug: project_data[:unlocked_by_lesson_slug])
      project.unlocked_by_lesson = lesson if lesson
    end

    project.save!
    puts "  ✓ Loaded project: #{project.title}"
  end

  puts "✓ Successfully loaded #{projects_data.size} project(s)!"
else
  puts "⚠ No projects.json found at #{projects_file}"
end

# Create some user progress data for testing
puts "\nCreating sample user progress..."

# Get first few levels and lessons
first_level = course.levels.first
second_level = course.levels.second

if first_level && second_level
  # Create user_course enrollment
  user_course = UserCourse.find_or_create_by!(user: user, course: course)

  # Create user_level records
  user_level_1 = UserLevel.find_or_create_by!(user: user, level: first_level)
  user_level_2 = UserLevel.find_or_create_by!(user: user, level: second_level)

  # Update user_course to point to current level
  user_course.update!(current_user_level: user_level_2)

  # Create user_lesson records for first level (mix of completed and started)
  first_level.lessons.limit(3).each_with_index do |lesson, index|
    UserLesson.find_or_create_by!(user: user, lesson: lesson) do |ul|
      ul.completed_at = index < 2 ? Time.current : nil
    end
  end

  # Create user_lesson records for second level (only started)
  second_level.lessons.limit(2).each do |lesson|
    UserLesson.find_or_create_by!(user: user, lesson: lesson)
  end

  puts "✓ Created sample progress for user #{user.email}"
  puts "  - Enrolled in course: #{course.title}"
  puts "  - #{user.user_levels.count} user_levels"
  puts "  - #{user.user_lessons.count} user_lessons (#{user.user_lessons.where.not(completed_at: nil).count} completed)"
end

# Create email templates for level 1 completion
puts "\nCreating email templates for level 1 completion..."

# English template
EmailTemplate.find_or_create_by!(
  type: :level_completion,
  slug: Level.first.slug,
  locale: "en"
) do |template|
  template.subject = "Congratulations {{ user.name }}! You've completed {{ level.title }}!"
  template.body_mjml = <<~MJML
    <mj-section background-color="#ffffff">
      <mj-column>
        <mj-text>
          <h1 style="color: #0066cc; font-size: 28px; font-weight: bold;">Congratulations, {{ user.name }}!</h1>
        </mj-text>

        <mj-text>
          <p style="font-size: 16px; line-height: 24px;">
            You've just completed <strong>{{ level.title }}</strong> (Level {{ level.position }})!
          </p>
        </mj-text>

        <mj-text>
          <p style="font-size: 16px; line-height: 24px;">
            {{ level.description }}
          </p>
        </mj-text>

        <mj-text>
          <p style="font-size: 16px; line-height: 24px;">
            This is an incredible milestone in your learning journey. Keep up the amazing work!
          </p>
        </mj-text>

        <mj-button href="https://jiki.io" background-color="#0066cc" color="#ffffff">
          Continue Learning
        </mj-button>

        <mj-text>
          <p style="font-size: 14px; color: #666666; margin-top: 20px;">
            Ready for the next challenge? Log in to continue your progress!
          </p>
        </mj-text>
      </mj-column>
    </mj-section>
  MJML
  template.body_text = <<~TEXT
    Congratulations, {{ user.name }}!

    You've just completed {{ level.title }} (Level {{ level.position }})!

    {{ level.description }}

    This is an incredible milestone in your learning journey. Keep up the amazing work!

    Continue Learning: https://jiki.io

    Ready for the next challenge? Log in to continue your progress!
  TEXT
end

# Hungarian template
EmailTemplate.find_or_create_by!(
  type: :level_completion,
  slug: Level.first.slug,
  locale: "hu"
) do |template|
  template.subject = "Gratulálunk {{ user.name }}! Teljesítetted a(z) {{ level.title }} szintet!"
  template.body_mjml = <<~MJML
    <mj-section background-color="#ffffff">
      <mj-column>
        <mj-text>
          <h1 style="color: #0066cc; font-size: 28px; font-weight: bold;">Gratulálunk, {{ user.name }}!</h1>
        </mj-text>

        <mj-text>
          <p style="font-size: 16px; line-height: 24px;">
            Épp most teljesítetted a(z) <strong>{{ level.title }}</strong> szintet ({{ level.position }}. szint)!
          </p>
        </mj-text>

        <mj-text>
          <p style="font-size: 16px; line-height: 24px;">
            {{ level.description }}
          </p>
        </mj-text>

        <mj-text>
          <p style="font-size: 16px; line-height: 24px;">
            Ez egy hihetetlen mérföldkő a tanulási utadon. Csak így tovább!
          </p>
        </mj-text>

        <mj-button href="https://jiki.io" background-color="#0066cc" color="#ffffff">
          Tanulás Folytatása
        </mj-button>

        <mj-text>
          <p style="font-size: 14px; color: #666666; margin-top: 20px;">
            Készen állsz a következő kihívásra? Jelentkezz be a folytatáshoz!
          </p>
        </mj-text>
      </mj-column>
    </mj-section>
  MJML
  template.body_text = <<~TEXT
    Gratulálunk, {{ user.name }}!

    Épp most teljesítetted a(z) {{ level.title }} szintet ({{ level.position }}. szint)!

    {{ level.description }}

    Ez egy hihetetlen mérföldkő a tanulási utadon. Csak így tovább!

    Tanulás Folytatása: https://jiki.io

    Készen állsz a következő kihívásra? Jelentkezz be a folytatáshoz!
  TEXT
end

puts "✓ Created email templates for level-1 in English and Hungarian"

# Create badges
puts "\nCreating badges..."

# Create all available badges using their STI classes
badge_classes = [
  Badges::MemberBadge,
  Badges::MazeNavigatorBadge,
  Badges::TestSecretBadge,
  Badges::FirstLessonBadge,
  Badges::EarlyBirdBadge,
  Badges::LevelCompletionistBadge,
  Badges::RapidLearnerBadge
]

badge_classes.each do |badge_class|
  badge = badge_class.find_or_create_by!(type: badge_class.name) do |b|
    # Trigger before_create callback to set attributes from seed data
  end
  puts "  ✓ Created badge: #{badge.name} (#{badge.secret? ? 'secret' : 'public'})"
end

puts "✓ Successfully created #{badge_classes.count} badges!"

# Create user badge acquisitions to demonstrate all possible states
puts "\nCreating user badge acquisitions (all states)..."

# Get admin user (the one you're probably logged in as)
admin_user = User.find_by(email: "ihid@jiki.io")

member_badge = Badges::MemberBadge.first
maze_badge = Badges::MazeNavigatorBadge.first  
secret_badge = Badges::TestSecretBadge.first
first_lesson_badge = Badges::FirstLessonBadge.first
early_bird_badge = Badges::EarlyBirdBadge.first
level_completionist_badge = Badges::LevelCompletionistBadge.first
rapid_learner_badge = Badges::RapidLearnerBadge.first

if admin_user
  # State 1: LOCKED badges (no User::AcquiredBadge record exists)
  # maze_badge and rapid_learner_badge are locked for test user
  puts "  ✓ Maze Navigator badge: LOCKED (hasn't completed maze lesson)"
  puts "  ✓ Rapid Learner badge: LOCKED (hasn't completed 3 lessons in one day)"
  puts "  ✓ Level Completionist badge: LOCKED (hasn't completed a full level)"
  
  # State 2: NEW/UNREVEALED badges (earned but not seen - revealed: false)
  User::AcquiredBadge.find_or_create_by!(user: admin_user, badge: member_badge) do |ab|
    ab.revealed = false
    ab.created_at = 1.day.ago
  end
  puts "  ✓ Member badge: NEW/UNREVEALED (earned but not seen)"
  
  User::AcquiredBadge.find_or_create_by!(user: admin_user, badge: first_lesson_badge) do |ab|
    ab.revealed = false
    ab.created_at = 1.hour.ago
  end
  puts "  ✓ First Steps badge: NEW/UNREVEALED (just earned)"
  
  # State 3: SEEN/REVEALED badges (earned and seen - revealed: true)  
  User::AcquiredBadge.find_or_create_by!(user: admin_user, badge: secret_badge) do |ab|
    ab.revealed = true
    ab.created_at = 2.days.ago
  end
  puts "  ✓ Test Secret badge: SEEN/REVEALED (secret badge, earned and seen)"
  
  User::AcquiredBadge.find_or_create_by!(user: admin_user, badge: early_bird_badge) do |ab|
    ab.revealed = true
    ab.created_at = 3.days.ago
  end
  puts "  ✓ Early Bird badge: SEEN/REVEALED (secret early access badge)"
  
  puts "✓ Successfully created badge acquisitions demonstrating all states!"
  puts "\n  Badge States Summary for user #{admin_user.email}:"
  puts "    LOCKED (not earned):"
  puts "       - Maze Navigator (needs to complete maze lesson)"
  puts "       - Rapid Learner (needs 3 lessons in one day)"
  puts "       - Level Completionist (needs to complete full level)"
  puts "    NEW/UNREVEALED (earned, not seen):"
  puts "       - Member (just joined)"
  puts "       - First Steps (just completed first lesson)"
  puts "    SEEN/REVEALED (earned and seen):"
  puts "       - Test Secret (secret badge, revealed)"
  puts "       - Early Bird (secret early access badge, revealed)"
else
  puts "⚠ Could not create badge acquisitions - missing admin user"
end

# Create sample payments for admin user
puts "\nCreating sample payments..."

if admin_user
  # Create 4 payments for admin user spanning several months
  [
    { months_ago: 4, product: "premium", amount: 1999 },
    { months_ago: 3, product: "premium", amount: 1999 },
    { months_ago: 2, product: "max", amount: 4999 },
    { months_ago: 1, product: "max", amount: 4999 }
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

  puts "  ✓ Created 4 payments for admin user (#{admin_user.email})"
  puts "    - 2 premium payments ($19.99 each)"
  puts "    - 2 max payments ($49.99 each)"
else
  puts "⚠ Could not create payments - missing admin user"
end

# Note: test user has no payments (deliberately left without payments for testing)