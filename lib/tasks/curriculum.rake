namespace :curriculum do
  # Cross-references the slugs this repo seeds against the content files the
  # front-end repo authors.
  #
  # The front end owns all screen-rendered copy (titles, descriptions,
  # instructions) in curriculum/src. The API only stores slugs, so a slug here
  # with no matching content there renders as a blank title with no error
  # anywhere. This is the check that catches that, and it is the only thing
  # coupling the two repos - there is no runtime dependency.
  #
  # Usage:
  #   bin/rails curriculum:verify_content              # defaults to ../front-end
  #   bin/rails curriculum:verify_content[/path/to/fe]
  desc "Verify every seeded slug has content in the front-end curriculum"
  # Deliberately no :environment dependency - this reads the seed JSON straight
  # off disk, so it needs neither a database nor a booted app.
  task :verify_content, [:fe_path] do |_task, args| # rubocop:disable Rails/RakeEnvironment
    fe_path = File.expand_path(args[:fe_path] || ENV.fetch('FRONT_END_PATH', '../front-end'), Rails.root)
    curriculum = File.join(fe_path, 'curriculum/src')

    abort "Front-end curriculum not found at #{curriculum}" unless Dir.exist?(curriculum)

    seeds = ->(file) { JSON.parse(File.read(Rails.root.join('db', 'seeds', file)), symbolize_names: true) }

    levels = seeds.('curriculum.json')[:levels]
    lessons = levels.flat_map { |level| level[:lessons] }

    # Only content the front end currently authors is checked. Videos,
    # challenges and badges have no catalogue there yet, so their copy still
    # lives in this repo and there is nothing to cross-reference.
    expectations = {
      'level' => levels.map { |level| [level[:slug], "levels/#{level[:slug]}.ts"] },
      'exercise' => lessons.select { |l| l[:type] == 'exercise' }.
        map { |l| [l[:slug], "exercises/#{l[:slug]}/instructions/source.md"] },
      'concept' => seeds.('concepts.json').map { |c| [c[:slug], "concepts/#{c[:slug]}/source.md"] }
    }

    missing = expectations.filter_map do |kind, entries|
      absent = entries.reject { |_slug, path| File.exist?(File.join(curriculum, path)) }
      [kind, absent] if absent.any?
    end

    checked = expectations.values.sum(&:size)

    if missing.empty?
      puts "✓ All #{checked} seeded slugs have front-end content (#{fe_path})"
      next
    end

    missing.each do |kind, entries|
      puts "\n#{entries.size} #{kind}(s) with no front-end content:"
      entries.each { |slug, path| puts "  #{slug} -> curriculum/src/#{path}" }
    end

    abort "\n#{missing.sum { |_, e| e.size }} of #{checked} seeded slugs are missing front-end content."
  end
end
