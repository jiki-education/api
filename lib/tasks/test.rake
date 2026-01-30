namespace :test do
  desc 'Test that Zeitwerk can load all files correctly'
  task zeitwerk: :environment do
    Rails.application.eager_load!
    puts 'Successfully loaded Rails. Zeitwerk is happy'
  end

  desc 'Validate Solid Queue recurring jobs configuration'
  task recurring_jobs: :environment do
    config_path = Rails.root.join('config', 'recurring.yml')
    unless File.exist?(config_path)
      puts 'No recurring.yml found, skipping validation'
      next
    end

    config = YAML.load_file(config_path, aliases: true) || {}
    errors = []

    config.each do |env, jobs|
      next unless jobs.is_a?(Hash)

      jobs.each do |job_name, job_config|
        next unless job_config.is_a?(Hash)
        next unless job_config['class']

        klass_name = job_config['class']
        begin
          klass_name.constantize
        rescue NameError
          errors << "#{env}.#{job_name}: class '#{klass_name}' does not exist"
        end
      end
    end

    if errors.any?
      puts "Recurring jobs validation failed:"
      errors.each { |e| puts "  - #{e}" }
      exit 1
    end

    puts 'Recurring jobs configuration is valid'
  end
end
