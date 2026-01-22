# LLM Integration

## Overview

Jiki uses direct Gemini API integration for AI-powered email translations. The system uses a synchronous approach where Sidekiq background jobs call the Gemini API directly and update templates immediately upon completion.

## Architecture

```
Rails API (EmailTemplate::TranslateToLocale)
  → Gemini::Translate command (HTTParty)
    → HTTP POST to Gemini API (synchronous)
      → Returns JSON response
      → Creates/Updates EmailTemplate directly
```

## Components

### Gemini::Translate Command

**File**: `app/commands/gemini/translate.rb`

**Purpose**: Direct HTTP client to call Google's Gemini API

**Usage**:
```ruby
Gemini::Translate.(
  prompt,          # Translation prompt
  model: :flash    # :flash or :pro
)

# Returns: { subject: "...", body_mjml: "...", body_text: "..." }
```

**Configuration**:
- Uses `Jiki.secrets.google_api_key` from jiki-config gem
- API endpoint: `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`
- Authentication: API key sent via `x-goog-api-key` header (not URL parameter)
- Models supported:
  - `:flash` → `gemini-2.5-flash` (default)
  - `:pro` → `gemini-2.5-pro`
- JSON Mode: Uses `responseMimeType: "application/json"` with `responseSchema` for structured output
- Sets `thinkingBudget: 0` in request for faster responses
- 60 second timeout for LLM response
- Uses HTTParty for HTTP requests

**Error Handling**:
- 429 (Rate Limit) → raises `Gemini::RateLimitError`
- 400 (Bad Request) → raises `Gemini::InvalidRequestError`
- Other errors → raises `Gemini::APIError`
- Invalid JSON response → raises `Gemini::InvalidRequestError`

**Request Structure**:
```ruby
{
  contents: [{
    parts: [{ text: prompt }]
  }],
  generationConfig: {
    responseMimeType: "application/json",
    responseSchema: {
      type: "object",
      properties: {
        subject: { type: "string" },
        body_mjml: { type: "string" },
        body_text: { type: "string" }
      },
      required: %w[subject body_mjml body_text]
    },
    thinkingConfig: {
      thinkingBudget: 0  # Disable thinking mode for faster responses
    }
  }
}
```

**Authentication**:
- API key sent via `x-goog-api-key` HTTP header
- This prevents key exposure in server logs and URLs

**Response Parsing**:
- Extracts text from: `response.candidates[0].content.parts[0].text`
- With `responseMimeType: "application/json"`, Gemini returns raw JSON (no markdown fences)
- Parses the text as JSON to get translation fields
- Returns hash with `:subject`, `:body_mjml`, `:body_text` keys

### EmailTemplate::TranslateToLocale

**File**: `app/commands/email_template/translate_to_locale.rb`

**Purpose**: Translate a single email template to a target locale

**Features**:
- Calls Gemini API directly via `Gemini::Translate`
- Creates template with translated content immediately (no placeholder)
- Validates source is English, target is supported locale
- Builds comprehensive translation prompt with context
- Re-raises `Gemini::RateLimitError` to allow Sidekiq retry

**Usage**:
```ruby
source_template = EmailTemplate.find_for(:level_completion, "basics-1", "en")

# Synchronous execution
EmailTemplate::TranslateToLocale.(source_template, "hu")

# Asynchronous execution via Sidekiq
EmailTemplate::TranslateToLocale.defer(source_template, "hu")
```

**Translation Prompt**:
- Localization expert persona
- Clear rules (preserve MJML, maintain tone, keep length)
- Context about template type and slug
- Shows all three fields (subject, body_mjml, body_text)
- Requests JSON response with specific fields

**Error Handling**:
- `Gemini::RateLimitError` → re-raised for Sidekiq retry with backoff
- Other Gemini errors → propagate up (will fail the job)
- Validation errors → raised before calling Gemini

### EmailTemplate::TranslateToAllLocales

**File**: `app/commands/email_template/translate_to_all_locales.rb`

**Purpose**: Batch translate template to all supported locales

**Features**:
- Queues background jobs for each locale
- Uses Sidekiq via Mandate's `.defer()` method
- Jobs run in `:translations` queue
- Validates source template is English

**Usage**:
```ruby
source_template = EmailTemplate.find_for(:level_completion, "basics-1", "en")
EmailTemplate::TranslateToAllLocales.(source_template)
```

## Admin Endpoint for Translation

### Triggering Translations via API

**Endpoint**: `POST /admin/email_templates/:id/translate`

**Purpose**: Queue translation jobs for all target locales for an English email template

**Authentication**: Requires admin authentication

**Request**:
```bash
POST /admin/email_templates/:id/translate
# Requires admin session (cookie-based authentication)
```

**Response (202 Accepted)**:
```json
{
  "email_template": {
    "id": 1,
    "type": "level_completion",
    "slug": "level-1",
    "locale": "en",
    "subject": "Congratulations!",
    "body_mjml": "...",
    "body_text": "..."
  },
  "queued_locales": ["hu", "fr"]
}
```

**Error Responses**:
- `404 Not Found` - Email template doesn't exist
- `422 Unprocessable Entity` - Template is not in English (source must be `en`)
  ```json
  {
    "error": "Source template must be in English (en)"
  }
  ```

**Behavior**:
- Calls `EmailTemplate::TranslateToAllLocales` to queue translation jobs
- Queues one `EmailTemplate::TranslateToLocale` job per target locale (hu, fr)
- Jobs are queued to the `:translations` Sidekiq queue
- Returns immediately (202 Accepted) while jobs process in background
- Translation results are stored in database as new EmailTemplate records

**Implementation**:
```ruby
# app/controllers/admin/email_templates_controller.rb
def translate
  target_locales = EmailTemplate::TranslateToAllLocales.(@email_template)
  render json: {
    email_template: SerializeAdminEmailTemplate.(@email_template),
    queued_locales: target_locales
  }, status: :accepted
rescue ArgumentError => e
  render json: { error: e.message }, status: :unprocessable_entity
end
```

## Exception Definitions

**File**: `config/initializers/exceptions.rb`

```ruby
module Gemini
  class Error < RuntimeError; end
  class RateLimitError < Error; end
  class InvalidRequestError < Error; end
  class APIError < Error; end
end
```

## Configuration

### Secrets Configuration

**Required**:
- `google_api_key` - Gemini API key from Google AI Studio

**Setup**:
1. Base secrets are in `../config/settings/secrets.yml` (fake value for development)
2. Override with your real key in `~/.config/jiki/secrets.yml`:
   ```yaml
   google_api_key: "your-real-api-key-here"
   ```
3. The personal secrets file is NOT checked into git

Access via `Jiki.secrets.google_api_key`

### Sidekiq Configuration

**File**: `config/sidekiq.yml`

The `:translations` queue is configured for LLM translation jobs:

```yaml
:queues:
  - critical
  - default
  - mailers
  - translations  # LLM translation jobs
  - background
  - low
```

### Mandate Queue Configuration

Translation commands explicitly set their queue using `queue_as`:

**File**: `app/commands/email_template/translate_to_locale.rb`
```ruby
class EmailTemplate::TranslateToLocale
  include Mandate

  queue_as :translations
  # ...
end
```

**File**: `app/commands/email_template/translate_to_all_locales.rb`
```ruby
class EmailTemplate::TranslateToAllLocales
  include Mandate

  queue_as :translations
  # ...
end
```

## Development Workflow

### Setting Up

```bash
# Configure your real Gemini API key
mkdir -p ~/.config/jiki
echo "google_api_key: \"your-real-api-key-here\"" > ~/.config/jiki/secrets.yml

# Start Sidekiq (for background jobs)
bundle exec sidekiq

# Start Rails
bin/rails server
```

### Testing Translation

```ruby
# In Rails console
template = EmailTemplate.find_for(:level_completion, "basics-1", "en")

# Synchronous execution (for testing)
translated = EmailTemplate::TranslateToLocale.(template, "hu")
puts translated.subject  # Shows translated subject immediately

# Asynchronous execution via Sidekiq (production mode)
EmailTemplate::TranslateToLocale.defer(template, "hu")

# Check Sidekiq Web UI at http://localhost:3000/sidekiq
# to monitor job progress

# Wait for job to complete, then check result
EmailTemplate.find_for(:level_completion, "basics-1", "hu")

# Translate to all locales
EmailTemplate::TranslateToAllLocales.(template)
```

### Monitoring

**Sidekiq Web UI**: `http://localhost:3000/sidekiq`
- View queued, processing, and failed jobs
- Retry failed jobs
- Monitor `:translations` queue

**Rails Logs**:
```
Translated level_completion/basics-1 → hu
```

**Sidekiq Logs**:
- Job enqueued
- Job started
- Job completed/failed
- Retry attempts

## Error Handling

### Rate Limiting

When Gemini returns 429:
1. `Gemini::Translate` raises `Gemini::RateLimitError`
2. `EmailTemplate::TranslateToLocale` re-raises it
3. Sidekiq automatically retries with exponential backoff
4. Check Sidekiq Web UI for retry schedule

### Invalid Requests

When Gemini returns 400 or invalid JSON:
1. `Gemini::Translate` raises `Gemini::InvalidRequestError`
2. Job fails
3. Review error message in Sidekiq Web UI
4. Fix prompt/request and retry manually

### API Errors

For other errors (500, network issues, etc.):
1. `Gemini::Translate` raises `Gemini::APIError`
2. Sidekiq retries automatically
3. After max retries, job moves to Dead queue
4. Manually retry from Sidekiq Web UI

## Testing

### Unit Tests

**Gemini::Translate Tests** (`test/commands/gemini/translate_test.rb`):
- Successful translation with mocked HTTP response
- Model selection (:flash vs :pro)
- x-goog-api-key header authentication
- JSON mode configuration (responseMimeType + responseSchema)
- thinkingBudget: 0 in request
- Error handling (429, 400, 500)
- Invalid JSON response
- Validation (missing API key, invalid model)

**EmailTemplate::TranslateToLocale Tests** (`test/commands/email_template/translate_to_locale_test.rb`):
- Creates translated template (not placeholder)
- Calls Gemini::Translate with correct params
- Upsert behavior (deletes existing)
- Validation tests
- Prompt generation tests
- Rate limit error handling

**EmailTemplate::TranslateToAllLocales Tests** (`test/commands/email_template/translate_to_all_locales_test.rb`):
- Enqueues jobs for all locales
- Uses .defer() for background execution
- Validates source is English

### Integration Testing

```bash
# Run all tests
bin/rails test

# Run LLM-related tests only
bin/rails test test/commands/gemini/
bin/rails test test/commands/email_template/
```

## Benefits of Synchronous Approach

1. **Simpler Architecture**: No separate Node.js LLM proxy needed
2. **Easier Deployment**: One less service to manage
3. **Better Error Handling**: Sidekiq's built-in retry logic with exponential backoff
4. **Easier Testing**: No need to mock HTTP callbacks
5. **Atomic Operations**: Translation completes or fails as one unit
6. **Better Observability**: Sidekiq Web UI shows real-time job status
7. **Code Reuse**: Same command works sync (`.()`) and async (`.defer()`)
8. **Faster Responses**: `thinkingBudget: 0` disables thinking mode

## Tradeoffs

1. **No Real-time Streaming**: Can't stream partial responses to UI
2. **Longer API Calls**: Sidekiq worker holds connection during translation (~10-30s)
3. **Worker Utilization**: Workers tied up during LLM API calls

Note: These tradeoffs are acceptable for batch translation workflows where immediate feedback is not required.

## Future Enhancements

- Translation caching (don't retranslate unchanged content)
- Quality metrics (translation time, success rate)
- Support for other LLM providers (OpenAI, Claude)
- Translation glossary/terminology management
- Human review workflow
- Batch processing optimization (multiple templates in one request)
- Dynamic model selection based on content complexity

## Related Documentation

- `.context/commands.md` - Mandate command pattern
- `.context/jobs.md` - Background job processing with Sidekiq
- `.context/configuration.md` - Jiki.config pattern

## Deprecated Components

### LLM::Exec (Unused)

**File**: `app/commands/llm/exec.rb`

**Status**: Kept for potential future use but currently unused

**Purpose**: Was used to call external LLM proxy service with async callbacks

**Rationale for keeping**: May want async callback pattern later for real-time streaming or other use cases that require decoupled processing.
