# ⚠️  AGENTS / REVIEWERS: READ THIS BEFORE TOUCHING THIS FILE ⚠️
#
# Seeds run repeatedly in production via the admin reseed endpoint, not just once
# at install. Everything in this file MUST be:
#
#   - Idempotent: running it repeatedly always produces the same result. No
#     duplicate records, no monotonically-growing counters, no "create" without
#     a matching "find_or_initialize_by" / uuid lookup.
#   - Non-destructive: records are only created or updated (matched by uuid, falling
#     back to slug), never deleted or recreated. User data is always preserved.
#   - Production-safe: no test users, sample progress or fake payments.
#     Development-only sample data lives in db/seeds/development.rb.
#
# EVERY PR THAT TOUCHES THIS FILE (or anything it loads) MUST explicitly verify
# idempotency: running `bin/rails db:seed` twice in a row must produce identical
# database state the second time. Call this out in the PR description.
#
# Run with: bin/rails db:seed

# == Course ==
course = Course.find_or_initialize_by(slug: "coding-fundamentals")
course.update!(
  title: "Coding Fundamentals",
  description: "Learn the fundamentals of programming through interactive exercises and videos."
)
puts "✓ Course: #{course.title}"

# == Levels and lessons ==
# Synced from curriculum.json, matched by uuid so slug renames, moves between levels
# and reordering all update existing records in place (preserving user progress).
sync_result = Level::CreateAllFromJson.(course, Rails.root.join("db", "seeds", "curriculum.json").to_s)
puts "✓ Levels: #{course.levels.count}, Lessons: #{Lesson.where(level: course.levels).count}"

if sync_result[:orphaned_levels].any? || sync_result[:orphaned_lessons].any?
  puts "⚠️  WARNING: The database contains levels/lessons that are not in curriculum.json."
  puts "   They have NOT been deleted (they may have user progress) but are still visible to users:"
  sync_result[:orphaned_levels].each { |slug| puts "   - level: #{slug}" }
  sync_result[:orphaned_lessons].each { |slug| puts "   - lesson: #{slug}" }
end

# == Concepts ==
concepts_file = Rails.root.join("db", "seeds", "concepts.json")
raise "Missing concepts seed file at #{concepts_file}" unless File.exist?(concepts_file)

concepts_data = JSON.parse(File.read(concepts_file), symbolize_names: true)

# First pass: create or update all concepts (matched by uuid, falling back to slug)
concepts_data.each do |concept_data|
  unlocking_lesson = nil
  if concept_data[:unlocked_by_lesson_slug]
    unlocking_lesson = Lesson.find_by(slug: concept_data[:unlocked_by_lesson_slug])
    unless unlocking_lesson
      raise "Concept '#{concept_data[:slug]}' references missing lesson '#{concept_data[:unlocked_by_lesson_slug]}'"
    end
  end

  concept = Concept.find_by(uuid: concept_data[:uuid]) ||
            Concept.find_or_initialize_by(slug: concept_data[:slug])

  concept.update!(
    uuid: concept_data[:uuid],
    slug: concept_data[:slug],
    title: concept_data[:title],
    description: concept_data[:description],
    unlocked_by_lesson: unlocking_lesson
  )
end
puts "✓ Concepts: #{concepts_data.size}"

# == Projects ==
projects_file = Rails.root.join("db", "seeds", "projects.json")
raise "Missing projects seed file at #{projects_file}" unless File.exist?(projects_file)

projects_data = JSON.parse(File.read(projects_file), symbolize_names: true)

projects_data.each do |project_data|
  unlocking_lesson = nil
  if project_data[:unlocked_by_lesson_slug]
    unlocking_lesson = Lesson.find_by(slug: project_data[:unlocked_by_lesson_slug])
    unless unlocking_lesson
      raise "Project '#{project_data[:slug]}' references missing lesson '#{project_data[:unlocked_by_lesson_slug]}'"
    end
  end

  project = Project.find_by(uuid: project_data[:uuid]) ||
            Project.find_or_initialize_by(slug: project_data[:slug])

  project.update!(
    uuid: project_data[:uuid],
    slug: project_data[:slug],
    title: project_data[:title],
    description: project_data[:description],
    exercise_slug: project_data[:exercise_slug],
    unlocked_by_lesson: unlocking_lesson
  )
end
puts "✓ Projects: #{projects_data.size}"

# == Badges ==
# Each Badges::* class defines its copy via `seed`. Create any missing badges and
# keep existing ones in sync with the class definitions.
Rails.application.eager_load!
Badge.subclasses.sort_by(&:name).each do |badge_class|
  badge = badge_class.first_or_initialize
  badge.update!(badge_class.seed_data) if badge_class.seed_data
end
puts "✓ Badges: #{Badge.subclasses.size}"

# == Admin user ==
# In production the password is random and unusable. To log in, set a real password
# via the bastion console (user.update!(password: "...")) or the password reset flow.
admin_user = User.find_or_create_by!(email: "ihid@jiki.io") do |u|
  u.handle = "iHiD"
  u.name = "Jeremy Walker"
  u.password = Rails.env.production? ? SecureRandom.hex(32) : "password"
end
admin_user.update!(admin: true) if Rails.env.production?
admin_user.confirm unless admin_user.confirmed?
UserCourse::Enroll.(admin_user, course)
puts "✓ Admin user: #{admin_user.email}"

# == Development sample data ==
load Rails.root.join("db", "seeds", "development.rb") if Rails.env.development?
