# Email Template Translation System - Implementation Plan

## Overview

Implement an AI-powered translation system for email templates that:
- Creates new `EmailTemplate` records for each locale (no complex state tracking)
- Uses LLM (Gemini) to translate subject, body_mjml, and body_text in a single API call
- Follows async callback pattern via LLM proxy service
- Fire-and-forget approach (overwrites duplicates if they occur)

## Architecture

```
EmailTemplate::TranslateToLocale (Rails)
  → LLM::Exec (Rails)
    → HTTP POST to LLM Proxy (Node.js)
      → Gemini API
      → Callback to SPI::LLMResponsesController#email_translation (Rails)
        → Updates EmailTemplate record
```

## Part 1: LLM Proxy Service

**Location**: `/Users/iHiD/Code/jiki/llm-proxy` (parallel to api/admin/front-end)

### Files to Create

1. **`package.json`**
   - [x] Dependencies: `@google/genai`, `express`, `ioredis`, `node-fetch`
   - [x] Dev dependencies: `husky`, `lint-staged`, `prettier`
   - [x] Type: `"module"`

2. **`lib/config.js`**
   - [x] Export `REDIS_URL` (default: `redis://127.0.0.1:6379/1`)
   - [x] Export `RAILS_SPI_BASE_URL` - load from `../config/settings/local.yml` → `spi_base_url`

3. **`lib/gemini.js`**
   - [x] Import Google GenAI SDK
   - [x] Export `handleGeminiPrompt(model, spiEndpoint, streamChannel, prompt)` function
   - [x] Makes streaming request to Gemini API
   - [x] Publishes chunks to Redis stream (for future real-time updates)
   - [x] On completion, POSTs full response to `${RAILS_SPI_BASE_URL}${spiEndpoint}`
   - [x] Error handling for rate limits (429), safety triggers, invalid requests

4. **`lib/server.js`**
   - [x] Express server on port 3064
   - [x] POST `/exec` endpoint
   - [x] Accepts: `{service, model, spi_endpoint, stream_channel, prompt}`
   - [x] Returns 202 immediately
   - [x] Calls `handleGeminiPrompt()` async
   - [x] Error handling: calls `/llm/rate_limited` or `/llm/errored` on failures
   - [x] Custom exceptions: `RateLimitException`, `InvalidRequestException`

5. **`bin/dev`**
   - [x] Bash script to install deps and start server
   - [x] `yarn install --frozen-lockfile`
   - [x] `node lib/server.js`

6. **`README.md`**
   - [x] Setup and usage instructions
   - [x] Environment variables needed
   - [x] Example curl command

### Key Changes from Exercism Version
- Load `RAILS_SPI_BASE_URL` from `../config/settings/local.yml` → `spi_base_url`
- Port 3064 (not 8080)
- Same API structure

## Part 2: Jiki Config Updates

**File**: `/Users/iHiD/Code/jiki/config/settings/local.yml`

- [x] Add `spi_base_url: http://localhost:3061/spi/`
- [x] Add `llm_proxy_url: http://localhost:3064/exec`

**Note**: This will be available to LLM proxy via `../config/settings/local.yml` and to Rails API via `Jiki.config.spi_base_url`

## Part 3: Rails API Changes

### 1. Create `LLM::Exec` Command

**File**: `app/commands/llm/exec.rb`

- [x] Include Mandate
- [x] Initialize with: `service, model, prompt, spi_endpoint, stream_channel: nil`
- [x] Validate all required params are present
- [x] POST to proxy URL (`Jiki.config.llm_proxy_url`)
- [x] Send payload: `{service, model, spi_endpoint: "llm/#{spi_endpoint}", stream_channel, prompt}`
- [x] Use HTTParty for HTTP POST

### 2. Create SPI Controller

**File**: `app/controllers/spi/base_controller.rb`

- [x] Inherit from `ActionController::API`
- [x] Skip CSRF verification for JSON requests
- [x] TODO comment about authentication for production

**File**: `app/controllers/spi/llm_responses_controller.rb`

- [x] Inherit from `SPI::BaseController`
- [x] Action: `email_translation`
  - [x] Find EmailTemplate by `params[:email_template_id]`
  - [x] Parse `params[:resp]` as JSON (symbolize keys)
  - [x] Update template with `subject`, `body_mjml`, `body_text` from response
  - [x] Return 200 OK
- [x] Action: `rate_limited` (placeholder for future retry logic)
- [x] Action: `errored` (placeholder for future error logging)

**Routes**: `config/routes.rb`

- [x] Add namespace `spi` with nested namespace `llm`
- [x] Route `post 'email_translation'` to `llm_responses#email_translation`
- [x] Route `post 'rate_limited'` to `llm_responses#rate_limited`
- [x] Route `post 'errored'` to `llm_responses#errored`

### 3. Create `EmailTemplate::TranslateToLocale` Command

**File**: `app/commands/email_template/translate_to_locale.rb`

- [x] Include Mandate
- [x] Initialize with: `source_template, target_locale`
- [x] Validation:
  - [x] Raise error if `source_template.locale != "en"`
  - [x] Raise error if `target_locale == "en"`
  - [x] Raise error if target_locale not in configured locales
- [x] Delete existing template if present (upsert pattern)
- [x] Create placeholder EmailTemplate record with:
  - [x] Same type and slug as source
  - [x] Target locale
  - [x] Empty subject, body_mjml, body_text
- [x] Build translation prompt with context
- [x] Call `LLM::Exec.(:gemini, :flash, prompt, spi_endpoint)`
- [x] Return new template

**Prompt Requirements**:
- [x] Clear instructions for localization expert
- [x] Rules: maintain meaning/tone, preserve length, don't translate MJML tags/attributes
- [x] Context: template type, slug, target locale name
- [x] Show all three fields to translate (subject, body_mjml, body_text)
- [x] Request JSON response with three fields

### 4. Create `EmailTemplate::TranslateToAllLocales` Command

**File**: `app/commands/email_template/translate_to_all_locales.rb`

- [x] Include Mandate
- [x] Initialize with: `source_template`
- [x] Validation:
  - [x] Raise error if `source_template.locale != "en"`
- [x] Get target locales: `(I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES) - ["en"]`
- [x] For each locale, call `EmailTemplate::TranslateToLocale.defer(source_template, locale)`

### 5. Configuration Updates

**File**: `config/locales/en.yml`

- [x] Add locale display names under `locales:` key:
  - `en: "English"`
  - `hu: "Hungarian"`
  - `fr: "French"`

**Config Gem Settings**:
- [x] Add `llm_proxy_url` to `../config/settings/local.yml` - `http://localhost:3064/exec`
- [x] Access via `Jiki.config.llm_proxy_url` in Rails code
- [x] Document `GOOGLE_API_KEY` - Gemini API key (environment variable used by LLM proxy Node.js process)
- [x] Document `REDIS_URL` - Redis connection for streaming (environment variable used by LLM proxy Node.js process)

### 6. Dependencies

**Gemfile**:
- [x] Add `gem 'httparty'`
- [x] Run `bundle install`

## Testing

### Unit Tests (Automated)

**LLM::Exec Command Tests** (`test/commands/llm/exec_test.rb`):
- [x] Test sends request to LLM proxy with correct payload
- [x] Test raises error when service is blank
- [x] Test raises error when model is blank
- [x] Test raises error when prompt is blank
- [x] Test raises error when spi_endpoint is blank
- [x] Test raises error when proxy returns non-success status
- [x] Test includes optional stream_channel in payload when provided
- [x] Test adds llm/ prefix to spi_endpoint

**SPI::LLMResponsesController Tests** (`test/controllers/spi/llm_responses_controller_test.rb`):
- [x] Test email_translation action updates template with translated content
- [x] Test email_translation handles missing template (404)
- [x] Test email_translation handles invalid JSON (422)
- [x] Test email_translation handles general errors (500)
- [x] Test rate_limited action logs error and returns 200
- [x] Test errored action logs error and returns 200

**EmailTemplate::TranslateToLocale Command Tests** (`test/commands/email_template/translate_to_locale_test.rb`):
- [x] Test creates placeholder template with correct attributes
- [x] Test calls LLM::Exec with correct parameters
- [x] Test raises error if source template is not English
- [x] Test raises error if target locale is English
- [x] Test raises error if target locale is not supported
- [x] Test deletes existing template before creating new one (upsert)
- [x] Test translation prompt includes all required context
- [x] Test translation prompt includes all three fields (subject, body_mjml, body_text)
- [x] Test translation prompt has localization expert instructions

**EmailTemplate::TranslateToAllLocales Command Tests** (`test/commands/email_template/translate_to_all_locales_test.rb`):
- [x] Test enqueues background jobs for all non-English locales
- [x] Test raises error if source template is not English
- [x] Test includes both SUPPORTED_LOCALES and WIP_LOCALES
- [x] Test excludes English from target locales
- [x] Test uses .defer() for background job execution

### Manual Testing Flow

1. [ ] Start Redis: `redis-server`
2. [ ] Start LLM Proxy: `cd ../llm-proxy && ./bin/dev`
3. [ ] Start Rails: `bin/rails server`
4. [ ] Create English template via admin UI or console
5. [ ] In Rails console:
   ```ruby
   template = EmailTemplate.find_for(:level_completion, "basics-1", "en")
   EmailTemplate::TranslateToLocale.(template, "hu")

   # Check that placeholder was created
   EmailTemplate.find_for(:level_completion, "basics-1", "hu")

   # Wait a few seconds for LLM response
   # Check again - should have translated content
   EmailTemplate.find_for(:level_completion, "basics-1", "hu")
   ```

### Integration Testing

- [ ] Source template validation (must be "en")
- [ ] Target locale validation (must be configured, cannot be "en")
- [ ] Placeholder template creation
- [ ] LLM callback updates template correctly
- [ ] MJML tags are not translated (only content)
- [ ] Variable placeholders preserved (e.g., `%{name}`)
- [ ] TranslateToAllLocales creates jobs for all locales
- [ ] Duplicate translations overwrite existing
- [ ] Error handling: LLM proxy unavailable
- [ ] Error handling: Gemini rate limit (429)
- [ ] Error handling: Invalid JSON response from Gemini
- [ ] Error handling: Missing email_template_id in callback

## Implementation Order

1. [x] Add `spi_base_url` and `llm_proxy_url` to `../config/settings/local.yml`
2. [x] Create `/Users/iHiD/Code/jiki/llm-proxy` directory structure
3. [x] Copy and adapt files from `exercism/llm-proxy`
4. [x] Update LLM proxy config to load `spi_base_url` from `../config/settings/local.yml`
5. [ ] Test LLM proxy standalone with curl
6. [x] Add `httparty` gem to Rails Gemfile
7. [x] Create `LLM::Exec` command
8. [x] Create SPI controller and routes
9. [x] Create `EmailTemplate::TranslateToLocale` command with prompt building
10. [x] Create `EmailTemplate::TranslateToAllLocales` command
11. [x] Add locale names to i18n YAML
12. [ ] Manual testing (full flow)
13. [x] Update `.context/` files with new translation patterns

## Before Committing

- [x] Run `bin/rails test` - all tests must pass
- [x] Run `bin/rubocop` - no linting errors
- [x] Run `bin/brakeman` - no security issues
- [x] Update `.context/commands.md` with LLM proxy startup
- [x] Update `.context/architecture.md` with LLM integration pattern

## Pull Requests

- [x] API PR #44: https://github.com/jiki-education/api/pull/44
- [x] Config PR #5: https://github.com/jiki-education/config/pull/5

## Future Enhancements

- Add authentication for SPI endpoints in production
- Implement retry logic in rate_limited/errored handlers
- Add ActionCable for real-time translation status updates in admin UI
- Track translation status/history
- Support for retranslating existing templates
- Glossary/terminology management for consistent translations
- Human review workflow
- Support for other content types (exercise instructions, etc.)
