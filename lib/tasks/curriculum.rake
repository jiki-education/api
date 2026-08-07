namespace :curriculum do
  # Thin wrapper over lib/curriculum_content_check.rb, which is plain Ruby so CI
  # can run it without booting the app. See that file for what it checks.
  #
  # Usage:
  #   bin/rails curriculum:verify_content              # defaults to ../front-end
  #   bin/rails curriculum:verify_content[/path/to/fe]
  desc "Verify every seeded slug has content in the front-end curriculum"
  task :verify_content, [:fe_path] do |_task, args| # rubocop:disable Rails/RakeEnvironment
    require_relative '../curriculum_content_check'

    path = File.expand_path(args[:fe_path] || ENV.fetch('FRONT_END_PATH', '../front-end'),
      CurriculumContentCheck::ROOT)
    status, message = CurriculumContentCheck.(path)

    puts message
    abort if status.nonzero?
  end
end
