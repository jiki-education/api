namespace :test do
  desc 'Test that Zeitwerk can load all files correctly'
  task zeitwerk: :environment do
    Rails.application.eager_load!
    puts 'Successfully loaded Rails. Zeitwerk is happy'
  end
end
