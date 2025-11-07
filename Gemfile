source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.0.rc1"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Authentication
gem "devise", "~> 4.9"
gem "devise-jwt", "~> 0.12.0"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
gem "rack-cors"

# Command pattern implementation for business logic
gem "mandate", "~> 2.0"

# Background job processing
gem "sidekiq", "~> 8.0"
gem "sidekiq-scheduler" # For scheduled/recurring jobs
gem "redis", "~> 5.0"

# Fast hashing for file deduplication
gem "xxhash"

# Email templating with MJML
gem "mjml-rails"
gem "mrml" # Rust-based MJML compiler (faster alternative to Node.js)

# HAML templating
gem "haml-rails"

# Liquid templating for user-editable email templates
gem "liquid"

# Configuration management
# Uses GitHub source for CI/production
# For local development, run: bundle config set --local local.jiki-config ../config
gem "jiki-config", github: "jiki-education/config", branch: "main"

# Pagination
gem "kaminari"

# HTTP client for external API integration
gem "httparty"

# AWS SDK for S3 storage
gem "aws-sdk-s3"

# Markdown parsing and HTML sanitization
gem "commonmarker"
gem "loofah"

# Friendly URLs with slug history
gem "friendly_id"

group :development, :test do
  # AWS SDK for Lambda (local development with LocalStack)
  gem "aws-sdk-lambda"

  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Test factories for creating test data
  gem "factory_bot_rails"

  # N+1 query detection
  gem "prosopite"
  gem "pg_query" # Required by Prosopite for PostgreSQL

  # Rubocop for code style enforcement
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-minitest", require: false
  gem "rubocop-performance", require: false
end

group :development do
  # Preview emails in browser during development
  gem "letter_opener"
end

group :test do
  # Mocking and stubbing framework
  gem "mocha"

  # HTTP request stubbing for external API testing
  gem "webmock"

  # Retry flaky tests in CI environments
  gem "minitest-retry"

  # Additional controller testing helpers
  gem "rails-controller-testing"

  # Fake data generation for tests
  gem "faker"
end
