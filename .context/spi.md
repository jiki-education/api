# SPI (Service Provider Interface)

This file documents the SPI pattern used for service-to-service communication in the Jiki API.

## What is SPI?

SPI endpoints are **network-guarded API endpoints** designed for service-to-service communication, distinct from user-facing API endpoints.

### Key Characteristics

- **No Authentication Required**: Security handled at network level (firewall/VPC rules in production)
- **Internal Communication**: Allow external services (Lambda, other microservices) to callback to Rails
- **Separate from User API**: Different base URL and routing namespace from `/v1/...` endpoints
- **Network-Level Security**: Production uses VPC rules or internal network endpoints

## URL Structure

### Development
- **User-facing API**: `http://localhost:3060` (frontend) → `http://localhost:3060` (Rails)
- **SPI Base URL**: `http://local.jiki.io:3060/spi` (configured in `jiki-config` gem)
- **Same Server**: Both URLs point to same Rails server in development

### Production
- **User-facing API**: `https://api.jiki.com` (public, requires authentication)
- **SPI Base URL**: `https://spi.jiki.com` or internal `http://10.0.1.5:3000/spi` (network-guarded, no auth)
- **Different Endpoints**: SPI may use internal network endpoint unreachable from public internet

## Configuration

**jiki-config gem** (`../config/settings/`):
```yaml
# local.yml and ci.yml
spi_base_url: http://local.jiki.io:3060/spi

# production.yml (TBD)
spi_base_url: https://spi.jiki.com/spi  # Or internal network endpoint
```

**Accessing in Rails:**
```ruby
Jiki.config.spi_base_url
# => "http://local.jiki.io:3060/spi" (development)
```

## Rails Implementation

### Base Controller

**File:** `app/controllers/spi/base_controller.rb`

```ruby
module Spi
  class BaseController < ActionController::API
    # No authentication - security at network level
    # Logs all SPI requests for audit
    before_action :log_spi_request
  end
end
```

### Routes

**File:** `config/routes.rb`

```ruby
namespace :spi do
  namespace :video_production do
    post :executor_callback
  end
end
```

**Generated routes:**
- `POST /spi/video_production/executor_callback` → `Spi::VideoProductionController#executor_callback`

### Controllers

**Pattern:** Inherit from `Spi::BaseController`, validate params, process request, return JSON

**Example:** `app/controllers/spi/video_production_controller.rb`
```ruby
module Spi
  class VideoProductionController < Spi::BaseController
    def executor_callback
      # 1. Validate required params
      # 2. Find the resource (e.g., node)
      # 3. Process callback using command object
      # 4. Return { status: 'ok' } or error
    end
  end
end
```

## Video Production SPI Integration

### Async Lambda Pattern

Lambda functions execute asynchronously and callback to SPI endpoint when complete.

**Flow:**
1. Rails executor invokes Lambda with `callback_url`, `node_uuid`, `executor_type` in payload
2. Lambda executes asynchronously (video processing, etc.)
3. Lambda POSTs result to `{spi_base_url}/video_production/executor_callback`
4. SPI controller calls `ProcessExecutorCallback` command
5. Command marks node as `completed` or `failed`

### Callback Payload

**Success:**
```json
{
  "node_uuid": "abc-123",
  "executor_type": "merge-videos",
  "result": {
    "s3_key": "pipelines/123/nodes/456/output.mp4",
    "duration": 10.5,
    "size": 1048576
  }
}
```

**Error:**
```json
{
  "node_uuid": "abc-123",
  "executor_type": "merge-videos",
  "error": "FFmpeg failed",
  "error_type": "ffmpeg_error"
}
```

### Stale Callback Handling

**Problem:** Callbacks can arrive after node execution has been superseded (retry, manual restart, etc.)

**Solution:** `ProcessExecutorCallback` checks:
1. Node status is `in_progress` (not `completed` or `failed`)
2. `process_uuid` in metadata matches current execution

If stale, raises `StaleCallbackError` (controller returns 200 to prevent retries, logs warning).

## Local Development Setup

### LocalStack Host Mapping

Lambda containers in LocalStack need to reach Rails server at `local.jiki.io`.

**File:** `bin/dev`
```bash
docker run \
  -e LAMBDA_DOCKER_FLAGS=--add-host=local.jiki.io:host-gateway \
  --add-host=local.jiki.io:host-gateway \
  ...
```

This configuration:
- `--add-host=local.jiki.io:host-gateway` - Maps hostname for LocalStack container itself
- `-e LAMBDA_DOCKER_FLAGS=--add-host=local.jiki.io:host-gateway` - Passes same flag to spawned Lambda containers (without quotes!)
- `host-gateway` resolves to host machine's IP from within containers

### Rails Server

Rails must be running to receive SPI callbacks:
```bash
bin/dev  # Starts Rails, Sidekiq, LocalStack
```

### Testing SPI Endpoints

**Manual test:**
```bash
curl -X POST http://local.jiki.io:3060/spi/video_production/executor_callback \
  -H "Content-Type: application/json" \
  -d '{
    "node_uuid": "...",
    "executor_type": "merge-videos",
    "result": {"s3_key": "test.mp4", "duration": 10, "size": 1024}
  }'
```

**Integration test:** See `test/controllers/spi/video_production_controller_test.rb`

## Security Considerations

### Development
- No authentication required (same server)
- All requests logged for audit

### Production
- **Network-Level Security**: VPC rules, security groups, internal network
- **No Public Access**: SPI endpoints not exposed to public internet
- **Firewall Rules**: Only allow specific IP ranges (Lambda VPC, trusted services)
- **Audit Logging**: All SPI requests logged with IP, timestamp, payload

### Why No Authentication?

- **Simplified Integration**: External services don't need to manage auth tokens
- **Performance**: No auth overhead for high-frequency callbacks
- **Network Trust**: Trust established at network/infrastructure level
- **Defense in Depth**: Combine with request validation, rate limiting, IP filtering

## Related Patterns

### llm-proxy Pattern

The SPI pattern follows the llm-proxy architecture in the jiki-education org:
- Async execution with callbacks
- Network-guarded endpoints
- No application-level authentication
- Audit logging for security

### Similar Use Cases

Other potential SPI endpoints:
- **Webhook callbacks**: Payment processors, email services
- **Internal microservices**: Service mesh communication
- **Batch job results**: External processing pipelines

## Testing

### Controller Tests

**File:** `test/controllers/spi/video_production_controller_test.rb`

Test scenarios:
- Successful callback processing
- Error callback processing
- Stale callback handling
- Missing parameters
- Non-existent resources

### Integration Tests

Use `INVOKE_LAMBDA_LOCALLY=true` to test full async flow with SPI callbacks in development.

## Key Files

- `app/controllers/spi/base_controller.rb` - Base controller for all SPI endpoints
- `app/controllers/spi/video_production_controller.rb` - Video production callbacks
- `app/commands/video_production/process_executor_callback.rb` - Callback processor
- `config/routes.rb` - SPI routes definition
- `.context/video_production.md` - Video production pipeline docs
