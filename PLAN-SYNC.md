# Synchronous Sidekiq Translation System - Implementation Plan

## Overview

Convert the email translation system from async LLM proxy callback pattern to synchronous Sidekiq jobs that directly call the Gemini API.

**Key Changes:**
- Remove SPI callback controller and routes
- Keep LLM::Exec command (unused but preserved for future use)
- Add direct Gemini API client to Rails
- Execute translations synchronously in Sidekiq background jobs
- Simpler architecture: Rails Job → Gemini API → Update Template

## Architecture

### Before (Async Callback)
```
EmailTemplate::TranslateToLocale (Rails)
  → LLM::Exec (Rails)
    → HTTP POST to LLM Proxy (Node.js)
      → Gemini API (async)
        → Callback to SPI::LLMResponsesController
          → Updates EmailTemplate
```

### After (Synchronous Sidekiq via Mandate)
```
EmailTemplate::TranslateToLocale.defer(source_template, target_locale)
  → Sidekiq Job (via Mandate's defer)
    → EmailTemplate::TranslateToLocale#call
      → Gemini::Client.translate (Rails)
        → Gemini API (sync)
        → Returns translation
      → Creates/Updates EmailTemplate directly
```

## Part 1: Add Gemini Client

### 1. Add HTTParty Gem

**File**: `Gemfile`

- [ ] Add `gem 'httparty'` (if not already present)
- [ ] Run `bundle install`

**Note**: We'll use HTTParty for cleaner HTTP requests with full control over the API request structure, including `thinkingBudget: 0`

### 2. Create Gemini Client

**File**: `app/services/gemini/client.rb`

- [ ] Class method: `translate(prompt, model: :flash)`
- [ ] Uses `GOOGLE_API_KEY` environment variable
- [ ] Supports two models:
  - `:flash` → `gemini-2.5-flash`
  - `:pro` → `gemini-2.5-pro`
- [ ] API endpoint: `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`
- [ ] Sets `thinkingBudget: 0` to disable thinking mode for faster responses
- [ ] Makes synchronous HTTP request to Gemini API
- [ ] Parses JSON response
- [ ] Error handling:
  - Rate limits (429) → raise `Gemini::RateLimitError`
  - Invalid request → raise `Gemini::InvalidRequestError`
  - Other errors → raise `Gemini::APIError`

**Example Usage:**
```ruby
response = Gemini::Client.translate(prompt, model: :flash)
# Returns: { subject: "...", body_mjml: "...", body_text: "..." }
```

**API Request Structure:**
```ruby
# POST to https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent
{
  "contents": [{
    "parts": [{ "text": prompt }]
  }],
  "generationConfig": {
    "thinkingConfig": {
      "thinkingBudget": 0  # Disable thinking for faster responses
    }
  }
}
```

### 3. Create Custom Exceptions

**File**: `app/services/gemini/errors.rb`

- [ ] `Gemini::Error` (base class)
- [ ] `Gemini::RateLimitError < Gemini::Error`
- [ ] `Gemini::InvalidRequestError < Gemini::Error`
- [ ] `Gemini::APIError < Gemini::Error`

## Part 2: Configure Mandate Queue and Retries

### 1. Configure Mandate for Translations Queue

**File**: `config/initializers/mandate.rb` (update existing)

- [ ] Configure queue name for translation commands:
```ruby
Mandate.configure do |config|
  # Use :translations queue for translation commands
  config.on_background_job_handler = lambda do |command, method_name|
    queue = if command.is_a?(EmailTemplate::TranslateToLocale) ||
               command.is_a?(EmailTemplate::TranslateToAllLocales)
              :translations
            else
              :default
            end

    { queue: queue }
  end
end
```

### 2. Configure Sidekiq Retries

**File**: `config/sidekiq.yml`

- [ ] Add retry configuration for rate limits:
```yaml
:queues:
  - [critical, 2]
  - [default, 5]
  - [translations, 3]
  - [low, 1]

# Retry configuration
:max_retries: 5

# Custom retry logic can be added to individual commands
```

## Part 3: Update Commands

### 1. Update EmailTemplate::TranslateToLocale

**File**: `app/commands/email_template/translate_to_locale.rb`

**Changes:**
- [ ] Remove LLM::Exec call
- [ ] Remove placeholder template creation (no longer needed)
- [ ] Add direct Gemini API call
- [ ] Create/update template with results
- [ ] Add retry logic for rate limits

**New Implementation:**
```ruby
class EmailTemplate::TranslateToLocale
  include Mandate

  initialize_with :source_template, :target_locale

  # Configure retries for rate limits
  on Gemini::RateLimitError do |e, command|
    raise e # Let Sidekiq handle retry with backoff
  end

  def call
    validate!

    # Call Gemini API directly
    translated = Gemini::Client.translate(
      translation_prompt,
      model: :flash
    )

    # Delete existing template if present (upsert pattern)
    EmailTemplate.find_for(source_template.type, source_template.slug, target_locale)&.destroy

    # Create new template with translated content
    target_template = EmailTemplate.create!(
      type: source_template.type,
      slug: source_template.slug,
      locale: target_locale,
      subject: translated[:subject],
      body_mjml: translated[:body_mjml],
      body_text: translated[:body_text]
    )

    Rails.logger.info "Translated #{source_template.type}/#{source_template.slug} → #{target_locale}"

    target_template
  end

  # ... rest of validation and prompt building unchanged
end
```

### 2. Keep EmailTemplate::TranslateToAllLocales Unchanged

**File**: `app/commands/email_template/translate_to_all_locales.rb`

- [ ] No changes needed
- [ ] Still calls `.defer()` on `TranslateToLocale`
- [ ] Mandate automatically queues via Sidekiq

## Part 4: Remove SPI Components

### 1. Delete SPI Controller

**Files to Delete:**
- [ ] `app/controllers/spi/base_controller.rb`
- [ ] `app/controllers/spi/llm_responses_controller.rb`
- [ ] `test/controllers/spi/llm_responses_controller_test.rb`

### 2. Remove SPI Routes

**File**: `config/routes.rb`

- [ ] Remove entire `namespace :spi` block

### 3. Keep LLM::Exec for Future Use

**Files to Keep (but unused):**
- `app/commands/llm/exec.rb` - Keep for potential future async use
- `test/commands/llm/exec_test.rb` - Keep tests

**Rationale**: May want async callback pattern later for real-time streaming

## Part 5: Configuration

### 1. Environment Variables

**Required:**
- `GOOGLE_API_KEY` - Gemini API key (same as before)

**Removed:**
- No longer need `llm_proxy_url` in config

### 2. Sidekiq Queue Configuration

**File**: `config/sidekiq.yml`

- [ ] Add `:translations` queue with appropriate concurrency
- [ ] Example:
```yaml
:queues:
  - [critical, 2]
  - [default, 5]
  - [translations, 3]
  - [low, 1]

:max_retries: 5
```

### 3. Mandate Configuration for Retries

Mandate integrates with Sidekiq, so retries are handled by Sidekiq's retry mechanism. For custom retry logic (like rate limit backoff), we can use Sidekiq's server middleware or rescue in the command.

## Part 6: Update Documentation

### 1. Update Context Files

**File**: `.context/llm.md`

- [ ] Update architecture diagram
- [ ] Document Gemini::Client
- [ ] Document TranslateEmailTemplateJob
- [ ] Remove SPI controller documentation
- [ ] Keep LLM::Exec docs but mark as "unused, for future async use"

**File**: `.context/jobs.md`

- [ ] Document that translation commands use Mandate's `.defer()` for background execution
- [ ] Document retry strategy via Sidekiq
- [ ] Document error handling in commands

### 2. Update README (if exists)

- [ ] Remove LLM proxy startup instructions
- [ ] Add `GOOGLE_API_KEY` to environment variables
- [ ] Update architecture section

## Testing Strategy

### Unit Tests

**File**: `test/services/gemini/client_test.rb`

- [ ] Test successful translation request
- [ ] Test rate limit error (429)
- [ ] Test invalid request error
- [ ] Test API error handling
- [ ] Test model selection (flash vs pro)
- [ ] Mock HTTP requests with WebMock

**Files to Update:**

`test/commands/email_template/translate_to_locale_test.rb`:
- [ ] Remove LLM::Exec stub/expectations
- [ ] Add Gemini::Client stub/expectations
- [ ] Test now calls Gemini directly
- [ ] Test template creation with translated content
- [ ] Test upsert behavior (deletes existing)
- [ ] Test Gemini::RateLimitError handling
- [ ] Keep all validation tests unchanged

`test/commands/email_template/translate_to_all_locales_test.rb`:
- [ ] No changes needed (still defers TranslateToLocale)

### Integration Tests

**Manual Testing:**
1. [ ] Start Sidekiq: `bundle exec sidekiq`
2. [ ] Start Rails: `bin/rails server`
3. [ ] In Rails console:
```ruby
template = EmailTemplate.find_for(:level_completion, "basics-1", "en")

# Synchronous execution (for testing)
EmailTemplate::TranslateToLocale.(template, "hu")

# Asynchronous execution via Sidekiq
EmailTemplate::TranslateToLocale.defer(template, "hu")

# Check Sidekiq started the job
# Check logs for Gemini API call
# Wait for job to complete
# Verify template was created/updated

EmailTemplate.find_for(:level_completion, "basics-1", "hu")

# Batch translation
EmailTemplate::TranslateToAllLocales.(template)
```

## Implementation Order

1. [ ] Add `httparty` gem (if not already present)
2. [ ] Create `Gemini::Client` service using HTTParty
3. [ ] Create `Gemini::Errors` module
4. [ ] Update `EmailTemplate::TranslateToLocale` to call Gemini directly
5. [ ] Delete SPI controllers and tests
6. [ ] Remove SPI routes
7. [ ] Update Sidekiq configuration (add :translations queue)
8. [ ] Update Mandate configuration (if needed for queue routing)
9. [ ] Write tests for Gemini::Client
10. [ ] Update EmailTemplate::TranslateToLocale tests
11. [ ] Update documentation files
12. [ ] Manual integration testing (sync and async with .defer)
13. [ ] Run quality checks (tests, rubocop, brakeman)

## Before Committing

- [ ] Run `bin/rails test` - all tests must pass
- [ ] Run `bin/rubocop` - no linting errors
- [ ] Run `bin/brakeman` - no security issues
- [ ] Update `.context/llm.md` with new architecture
- [ ] Update `.context/jobs.md` with new job

## Benefits of Synchronous Approach via Mandate

1. **Simpler Architecture**: No separate Node.js service needed
2. **Easier Deployment**: One less service to manage
3. **Better Error Handling**: Sidekiq's built-in retry logic
4. **Easier Testing**: No need to mock HTTP callbacks or jobs
5. **Atomic Operations**: Translation completes or fails as one unit
6. **Better Observability**: Sidekiq Web UI shows job status
7. **Code Reuse**: Same command works sync and async via `.defer()`
8. **No Job Boilerplate**: Mandate handles job wrapping automatically

## Tradeoffs

1. **No Real-time Streaming**: Can't stream partial responses to UI
2. **Longer API Calls**: Sidekiq worker holds connection during translation
3. **Worker Utilization**: Workers tied up during slow API calls

**Note**: With `thinkingBudget: 0`, Gemini 2.5 Flash responses are faster since thinking mode is disabled, reducing worker idle time.

## How Mandate .defer() Works

When you call `EmailTemplate::TranslateToLocale.defer(template, "hu")`:
1. Mandate serializes the command parameters
2. Enqueues a Sidekiq job
3. Sidekiq worker picks up the job
4. Mandate deserializes parameters
5. Calls `EmailTemplate::TranslateToLocale.(template, "hu")`
6. Result is discarded (fire-and-forget)

This means:
- Same code runs sync (`.()`) and async (`.defer()`)
- No need for separate job classes
- Easy to test synchronously
- Flexible execution model

## Future Enhancements

- Add Sidekiq status tracking for admin UI
- Add translation caching (don't retranslate unchanged content)
- Add quality metrics (translation time, success rate)
- Support for other LLM providers (OpenAI, Claude)
- Batch translation optimization (multiple templates in one request)
