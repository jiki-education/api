# Configuration

## Environment Configuration

### Configuration Pattern

**IMPORTANT**: Jiki uses the `Jiki.config.*` pattern for all configuration (see "Jiki Config Gem Pattern" section below). Never use `ENV` variables directly in application code.

### Database Configuration
- Config file: `config/database.yml`
- Development: Local PostgreSQL, database `jiki_development`
- Test: Local PostgreSQL, database `jiki_test`
- Production: Uses database configuration from config gem or Rails standard `DATABASE_URL`

### Rails Master Key
- Location: `config/master.key`
- Used for credentials encryption
- Required for production deployment
- Never commit to version control

### Framework-Level Environment Variables

These environment variables are used by Rails framework itself and cannot be replaced by config gem:

```bash
# Rails Framework (system-level only)
RAILS_ENV                 # Environment (development/test/production)
RAILS_MASTER_KEY          # Decryption key for credentials
RAILS_LOG_TO_STDOUT       # Enable stdout logging in production
RAILS_MAX_THREADS         # Connection pool size (default: 5)
```

**All application-level configuration** (database URLs, API keys, service URLs, etc.) **must use `Jiki.config.*`** instead of ENV variables. See the "Jiki Config Gem Pattern" section below.

## CORS Configuration

### Setup Location
- File: `config/initializers/cors.rb`
- Currently commented out (needs activation)

### Configuration Pattern
```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins Jiki.config.frontend_base_url
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
```

**Note**: Uses `Jiki.config.frontend_base_url` from config gem settings files (`../config/settings/*.yml`).

## Storage Configuration

### Active Storage Setup
- Config file: `config/storage.yml`
- Development: Local disk storage
- Test: Temporary test storage
- Production: AWS S3 (to be configured)

### S3 Configuration (Production)
```yaml
amazon:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: us-east-1
  bucket: jiki-storage
```

## Action Cable Configuration

### Setup Location
- File: `config/cable.yml`
- Development: Async adapter (in-memory)
- Test: Test adapter
- Production: Redis adapter

### Redis Configuration (Production)
```yaml
production:
  adapter: redis
  url: <%= Jiki.config.redis_url %>
  channel_prefix: jiki_production
```

**Note**: Uses `Jiki.config.redis_url` from config gem settings.

## Application Settings

### Time Zone
- Default: UTC
- Configure in `config/application.rb`:
```ruby
config.time_zone = 'UTC'
```

### Autoloading
- Zeitwerk autoloader (Rails default)
- Eager loading in production
- Lazy loading in development

### Middleware
- API-only middleware stack
- No session/cookie middleware by default
- Can add back if needed for specific features

## Docker Configuration

### Dockerfile Settings
- Ruby version: Matches `.ruby-version`
- Base image: Ruby slim for smaller size
- Multi-stage build for optimization
- Non-root user for security

### Container Environment
- Port: 80 (exposed)
- Workdir: `/rails`
- Entrypoint: `bin/docker-entrypoint`
- Default command: Thruster + Rails server

## CI/CD Configuration

### GitHub Actions
- File: `.github/workflows/ci.yml`
- Runs on push and pull requests
- Test matrix for multiple Ruby versions
- Database setup for tests

### Dependabot
- File: `.github/dependabot.yml`
- Automated dependency updates
- Security vulnerability alerts

## Development Tools Configuration

### RuboCop
- File: `.rubocop.yml`
- Rails Omakase style guide
- Run with `bin/rubocop`

### Brakeman
- Security scanner for Rails
- Run with `bin/brakeman`
- Configuration can be added to `.brakeman.yml`

## Testing Configuration

### Test Helper
- File: `test/test_helper.rb`
- Parallel test execution enabled
- Fixtures autoloaded
- Test environment setup

### Parallel Testing
- Workers: Number of processors
- Configured in test helper
- Speed up test suite execution

## Production Deployment Configuration

### Puma Web Server
- Config file: `config/puma.rb`
- Default port: 3060
- Worker processes
- Thread pool configuration
- Preload app for performance

### Thruster
- HTTP/2 support
- Asset caching
- Compression
- X-Sendfile acceleration

## Logging Configuration

### Development
- Log to `log/development.log`
- Debug level logging
- SQL query logging enabled

### Production
- Log to stdout (for container environments)
- Info level logging
- Structured logging recommended

## Security Configuration

### Parameter Filtering
- File: `config/initializers/filter_parameter_logging.rb`
- Filters sensitive parameters from logs
- Default: `:password`
- Add more as needed

### Content Security Policy
- Removed in API-only mode
- Can be re-added if serving any HTML

### HTTPS/SSL
- Enforced in production
- Handled by load balancer/CDN
- Force SSL in Rails: `config.force_ssl = true`

## Jiki Config Gem Pattern

### Overview
Following the Exercism pattern, Jiki will use a custom `jiki-config` gem to manage environment-specific configuration. This provides a clean abstraction over environment variables and external configuration sources.

### Pattern Details

**Development/Test**: Configuration loaded from YAML files
- Files: `settings/local.yml` and `settings/ci.yml`
- Simple, flat YAML structure with ERB support
- Easy to modify for local development

**Production**: Configuration loaded from DynamoDB
- Centralized configuration management
- No ENV vars hardcoded in application code
- Easy to update without code deploys

### Configuration Interface

All configuration accessed via `Jiki.config.*`:

```ruby
# Sidekiq Redis connection
Jiki.config.sidekiq_redis_url  # => "redis://localhost:6379/0"

# Future examples
Jiki.config.aws_s3_bucket      # => "jiki-production-storage"
Jiki.config.stripe_secret_key  # => Retrieved from secrets
```

### Implementation Status

**Current**: Uses `Jiki.config.*` pattern throughout
- Example: `config/initializers/sidekiq.rb` uses `Jiki.config.sidekiq_redis_url`
- Configuration loaded from YAML files in development/test
- Production will use DynamoDB (when implemented)

**Future**: Full DynamoDB integration for production (separate task)
- Structure: `lib/jiki.rb`, `lib/jiki_config/`
- Commands: `DetermineEnvironment`, `RetrieveConfig`, `RetrieveSecrets`
- Uses Zeitwerk for autoloading
- Settings files in `settings/` directory

### Related Configuration

**Sidekiq**: Uses `Jiki.config.sidekiq_redis_url`
```ruby
# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { url: Jiki.config.sidekiq_redis_url }
end
```

### Gem Source Configuration

The `jiki-config` gem is referenced differently in different environments:

**Local Development**: Uses `path: "../config"` - changes to config gem are immediately available
**CI/Production**: Will use published gem from gem source when available

The Gemfile automatically detects local development and uses path-based gem. To force gem source in development:
```bash
JIKI_USE_LOCAL_CONFIG=false bundle install
```

### Configuration Guidelines

**IMPORTANT**: Never use `ENV` vars directly in application code. Always use `Jiki.config.*` instead.

**Why?**
- Consistent interface across development, test, and production
- Development/test: Loads from YAML files in `../config/settings/`
- Production: Loads from DynamoDB
- Easy to switch configuration sources without code changes
- Centralized configuration management

**Examples:**

❌ **Wrong** - Don't do this:
```ruby
frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
```

✅ **Correct** - Use Jiki.config:
```ruby
frontend_url = Jiki.config.frontend_base_url
```

**Adding New Configuration Values:**

1. Add to `../config/settings/local.yml` for development
2. Add to `../config/settings/ci.yml` for CI/test
3. Add to DynamoDB for production (via deployment process)
4. Access via `Jiki.config.your_key_name`

### See Also
- Exercism's exercism-config gem at `../../exercism/config` for reference implementation
- Background job configuration in `.context/jobs.md`