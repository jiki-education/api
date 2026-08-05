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

  # Only content the front end currently authors is checked. Videos, challenges
  # and badges have no catalogue there yet, so their copy still lives in this
  # repo and there is nothing to cross-reference.
  module_function

  def call(fe_path)
    curriculum = File.join(fe_path, 'curriculum/src')
    return [1, "Front-end curriculum not found at #{curriculum}"] unless Dir.exist?(curriculum)

    missing = expectations.filter_map do |kind, entries|
      absent = entries.reject { |_slug, path| File.exist?(File.join(curriculum, path)) }
      [kind, absent] if absent.any?
    end

    checked = expectations.values.sum(&:size)
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
        map { |l| [l[:slug], "exercises/#{l[:slug]}/instructions/source.md"] },
      'concept' => seeds('concepts.json').map { |c| [c[:slug], "concepts/#{c[:slug]}/source.md"] }
    }
  end

  def seeds(file)
    JSON.parse(File.read(File.join(ROOT, 'db', 'seeds', file)), symbolize_names: true)
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
