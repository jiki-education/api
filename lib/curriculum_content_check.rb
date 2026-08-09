# Cross-references the slugs this repo seeds against the content files the
# front-end repo authors.
#
# The front end owns all screen-rendered copy (titles, descriptions,
# instructions) in curriculum/src. The API only stores slugs, so a slug here
# with no matching content there renders as a blank title with no error
# anywhere. This is the check that catches that, and it is the only thing
# coupling the two repos - there is no runtime dependency.
#
# Deliberately plain Ruby with no Rails: it reads the seed JSON straight off
# disk, so it needs no database, no booted app, and none of the app's native
# dependencies (which is why CI can run it on a bare Ruby setup).
#
#   ruby lib/curriculum_content_check.rb [path/to/front-end]
require 'json'

module CurriculumContentCheck
  ROOT = File.expand_path('..', __dir__)

  # Every domain whose copy the front end authors. Badges are enumerated from
  # the Badges::* classes rather than a seed file, so they are passed in.
  BADGE_SLUGS = %w[
    beta_user early_bird first_lesson maze_navigator member
    night_owl premium scenario_handler sidekick townsfolk
  ].freeze

  module_function

  def call(fe_path)
    curriculum = File.join(fe_path, 'curriculum/src')
    return [1, "Front-end curriculum not found at #{curriculum}"] unless Dir.exist?(curriculum)

    missing = expectations.filter_map do |kind, entries|
      absent = entries.reject { |_slug, path| File.exist?(File.join(curriculum, path)) }
      [kind, absent] if absent.any?
    end

    missing += keyed_expectations.filter_map do |kind, (path, slugs)|
      keys = catalogue_keys(File.join(curriculum, path))
      absent = slugs.reject { |slug| keys.include?(slug) }.map { |slug| [slug, path] }
      [kind, absent] if absent.any?
    end

    checked = expectations.values.sum(&:size) + keyed_expectations.values.sum { |_, slugs| slugs.size }
    return [0, "✓ All #{checked} seeded slugs have front-end content (#{fe_path})"] if missing.empty?

    [1, report(missing, checked)]
  end

  def report(missing, checked)
    lines = missing.map do |kind, entries|
      ["\n#{entries.size} #{kind}(s) with no front-end content:",
       *entries.map { |slug, path| "  #{slug} -> curriculum/src/#{path}" }]
    end

    total = missing.sum { |_, entries| entries.size }
    [*lines.flatten, "\n#{total} of #{checked} seeded slugs are missing front-end content."].join("\n")
  end

  def expectations
    levels = seeds('curriculum.json')[:levels]
    lessons = levels.flat_map { |level| level[:lessons] }

    {
      'level' => levels.map { |level| [level[:slug], "levels/#{level[:slug]}.ts"] },
      'exercise' => lessons.select { |l| l[:type] == 'exercise' }.
        map { |l| [l[:slug], "exercises/#{l[:slug]}/instructions.md"] },
      'concept' => seeds('concepts.json').map { |c| [c[:slug], "concepts/#{c[:slug]}/source.md"] },
      # Challenges are exercises on the front end, reached via exercise_slug.
      'challenge' => seeds('challenges.json').
        map { |c| [c[:slug], "exercises/#{c[:exercise_slug]}/instructions.md"] }
    }
  end

  # Video lessons and badges are keyed inside a single English source catalogue
  # rather than getting a file each, so they are checked by key.
  def keyed_expectations
    lessons = seeds('curriculum.json')[:levels].flat_map { |level| level[:lessons] }

    {
      'video lesson' => ['video-lessons/messages.json',
                         lessons.select { |l| l[:type] == 'video' }.map { |l| l[:slug] }],
      'badge' => ['badges/messages.json', BADGE_SLUGS]
    }
  end

  def seeds(file)
    JSON.parse(File.read(File.join(ROOT, 'db', 'seeds', file)), symbolize_names: true)
  end

  # A missing catalogue file means every slug in it is missing, which the
  # caller reports one by one.
  def catalogue_keys(path)
    File.exist?(path) ? JSON.parse(File.read(path)).keys : []
  end
end

# Command-line entrypoint: this runs as a bare script outside the Rails app, so
# stdout and a real exit status are the interface CI reads.
if $PROGRAM_NAME == __FILE__
  path = File.expand_path(ARGV[0] || ENV.fetch('FRONT_END_PATH', '../front-end'), CurriculumContentCheck::ROOT)
  status, message = CurriculumContentCheck.(path)
  puts message # rubocop:disable Rails/Output
  exit status # rubocop:disable Rails/Exit
end
