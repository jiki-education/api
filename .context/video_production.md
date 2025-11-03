# Video Production Pipeline

This file documents the video production pipeline system for orchestrating AI-generated video content.

## Overview

The video production system allows admins to create and execute complex video generation workflows through a visual pipeline editor. The Rails API manages pipeline state, coordinates background jobs, and integrates with external APIs (HeyGen, ElevenLabs, Veo 3) and Lambda functions (FFmpeg processing).

## Architecture

```
┌─────────────────────────────────────────────────┐
│          Next.js Visual Editor                  │
│     (code-videos repo - UI only)                │
│  • React Flow pipeline designer                 │
│  • Read-only database access                    │
│  • Calls Rails API for execution                │
└─────────────────┬───────────────────────────────┘
                  │
                  │ POST /v1/admin/video_production/.../nodes
                  │ GET  /v1/admin/video_production/...
                  ↓
┌─────────────────────────────────────────────────┐
│           Rails API (this repo)                 │
│  • CRUD operations for pipelines/nodes          │
│  • Input validation                             │
│  • Database writes (status, metadata, output)   │
│  • Sidekiq executors & polling jobs             │
└─────────────────┬───────────────────────────────┘
                  │
         ┌────────┼────────┬────────┬──────────┐
         ↓        ↓        ↓        ↓          ↓
    ┌────────┐ ┌─────┐ ┌──────┐ ┌────────┐ ┌────┐
    │ Lambda │ │HeyGen│ │ Veo3 │ │Eleven  │ │ S3 │
    │(FFmpeg)│ │ API  │ │ API  │ │Labs API│ │    │
    └────────┘ └─────┘ └──────┘ └────────┘ └────┘
```

## Services Structure

Lambda functions and deployment configuration live in `services/video_production/`:

```
services/video_production/
├── README.md                    # Deployment guide and architecture
├── template.yaml                # AWS SAM deployment config
└── video-merger/                # FFmpeg video concatenation Lambda
    ├── index.js
    ├── package.json
    └── README.md
```

All Ruby code (executors, API clients, utilities) remains in `app/commands/video_production/`.

## Database Schema

**Schema files:** See `db/migrate/*_create_video_production_*.rb`

### Shared Database Pattern

Both Next.js (code-videos) and Rails connect to the same database. Column ownership prevents conflicts:

- **Next.js writes**: `type`, `inputs`, `config`, `asset`, `title`
- **Rails writes**: `status`, `metadata`, `output`, `is_valid`, `validation_errors`

### Tables Overview

**video_production_pipelines:** UUID primary key, JSONB columns for `config` (storage/directory settings) and `metadata` (cost tracking, progress statistics)

**video_production_nodes:** UUID primary key with pipeline foreign key. Structure columns (Next.js), execution state columns (Rails), validation state columns (Rails).

**Node Types:** `asset`, `generate-talking-head`, `generate-animation`, `generate-voiceover`, `render-code`, `mix-audio`, `merge-videos`, `compose-video`

**Status Values:** `pending`, `in_progress`, `completed`, `failed`

## Models

### VideoProduction::Pipeline (`app/models/video_production/pipeline.rb`)

- Has many nodes (cascade delete)
- Auto-generates UUID on create
- JSONB accessors: `storage`, `working_directory`, `total_cost`, `estimated_total_cost`, `progress`
- `progress_summary` method returns node progress counts from metadata

### VideoProduction::Node (`app/models/video_production/node.rb`)

- Uses `disable_sti!` to prevent Rails STI on `type` column
- Belongs to pipeline
- Auto-generates UUID on create
- JSONB accessors for config (provider), metadata (process_uuid, timestamps, error, cost), output (s3_key, duration, size)
- Scopes: `pending`, `in_progress`, `completed`, `failed`
- `inputs_satisfied?` - Checks if all input nodes are completed
- `ready_to_execute?` - Returns true if pending, valid, and inputs satisfied

## Schema-Based Validation

Each node type has a schema class in `app/commands/video_production/node/schemas/` that defines:
- **INPUTS** - Input slot definitions (types, requirements, constraints)
- **CONFIG** - Configuration field definitions (types, allowed values, requirements)

**Schema Structure:**
- Input types: `:single` (one node reference) or `:multiple` (array of references with min/max counts)
- Config types: `:string`, `:integer`, `:boolean`, `:array`, `:hash`
- Common properties: `required`, `allowed_values`, `description`, `min_count`, `max_count`

**Validation Commands:**
- `VideoProduction::Node::Validate` - Main orchestrator that calls ValidateInputs and ValidateConfig, updates `is_valid` and `validation_errors` columns
- `VideoProduction::Node::ValidateInputs` - Validates input slots against schema, checks node references exist
- `VideoProduction::Node::ValidateConfig` - Validates config fields against schema, checks types and allowed values

Validation runs automatically on node create/update. Nodes with `is_valid: false` cannot execute (`ready_to_execute?` checks this).

## Commands

All commands in `app/commands/video_production/` use the Mandate pattern (see `.context/architecture.md`).

**Pipeline CRUD:**
- `Pipeline::Create` - Creates pipeline with title, version, config, metadata
- `Pipeline::Update` - Updates pipeline attributes
- `Pipeline::Destroy` - Deletes pipeline (cascades to nodes)

**Node CRUD:**
- `Node::Create` - Creates node and runs validation (raises `VideoProductionBadInputsError` on failure)
- `Node::Update` - Updates node, resets status to `pending` if structure fields (`inputs`, `config`, `asset`) change
- `Node::Destroy` - Deletes node and cleans up references (removes UUID from array inputs, removes entire slot for single inputs)

## Controllers & Serializers

**Controllers:** Admin-only CRUD at `/v1/admin/video_production/*` (see Routes below)
- `PipelinesController` - Index (paginated 25/page), show, create, update, destroy
- `NodesController` - Nested under pipelines, index, show, create (validates), update (validates, resets status), destroy (cleans refs)
- Returns 404 for not found, 422 for validation errors

**Serializers:** All in `app/serializers/` using Mandate pattern
- `SerializeAdminVideoProductionPipeline(s)` - Pipeline with UUID, title, version, config, metadata (optionally includes nodes)
- `SerializeAdminVideoProductionNode(s)` - Node with all fields including validation state

## Routes

Nested resources under `/v1/admin/video_production/`:
- `pipelines` - Standard REST actions (index, show, create, update, destroy) using `:uuid` param
- `pipelines/:pipeline_uuid/nodes` - Nested nodes with same REST actions using `:uuid` param

## Testing

### Model Tests

Location: `test/models/video_production/`
- `pipeline_test.rb` - 38 tests for Pipeline model
- `node_test.rb` - 38 tests for Node model

### Command Tests

Location: `test/commands/video_production/`
- `node/validate_inputs_test.rb` - 20 tests for input validation

### Controller Tests

Location: `test/controllers/v1/admin/video_production/`
- `pipelines_controller_test.rb` - 30 tests for pipeline CRUD
- `nodes_controller_test.rb` - 41 tests for node CRUD

**Total:** 167 tests covering Phase 1 and Phase 2

### Test Patterns

```ruby
# FactoryBot factories
pipeline = create(:video_production_pipeline)
node = create(:video_production_node, pipeline: pipeline)

# With traits
node = create(:video_production_node, :completed)
node = create(:video_production_node, :merge_videos)

# Controller authentication
guard_admin! :v1_admin_video_production_pipelines_path, method: :get

# Error testing
assert_raises(VideoProductionBadInputsError) do
  VideoProduction::Node::ValidateInputs.('asset', { 'foo' => ['bar'] }, pipeline.id)
end
```

## Execution System

### Execution Lifecycle Commands

All execution commands follow a strict lifecycle to prevent race conditions and ensure data integrity.

**Execution Lifecycle:**
1. `ExecutionStarted` - Marks node as `in_progress`, generates unique `process_uuid`
2. `ExecutionUpdated` - Updates metadata during processing (with UUID verification)
3. `ExecutionSucceeded` or `ExecutionFailed` - Completes execution (with UUID verification)

**Execution Lifecycle Commands** (`app/commands/video_production/node/`):

1. `ExecutionStarted` - Sets status to `in_progress`, generates unique `process_uuid`, sets `started_at`, returns UUID for tracking
2. `ExecutionUpdated` - Updates metadata during processing (verifies process_uuid matches, silently exits on mismatch)
3. `ExecutionSucceeded` - Sets status to `completed`, stores output, sets `completed_at` (verifies process_uuid)
4. `ExecutionFailed` - Sets status to `failed`, stores error message, sets `completed_at` (verifies process_uuid, accepts nil for pre-execution failures)

All use `with_lock` for atomicity. UUID verification prevents stale jobs from corrupting state.

### Race Condition Protection

The execution system implements comprehensive protection against three types of race conditions:

**1. Webhook Double-Processing**
- Problem: Webhook arrives before/during polling job
- Solution: `CheckForResult` verifies status is still `in_progress` before processing

**2. Concurrent Executions**
- Problem: Second execution starts while first is still running
- Solution: Each execution has unique `process_uuid`; all completion commands verify UUID matches

**3. Check-Then-Update Races**
- Problem: Status/UUID read and write not atomic
- Solution: All commands use `node.with_lock` to make read-check-write operations atomic

**Stale Job Behavior:**
- When UUID mismatch detected, commands silently exit
- No errors raised (normal distributed systems behavior)
- Current execution continues unaffected

### Executors

Node executors are Sidekiq jobs that process individual nodes. Each executor handles a specific node type and follows the execution lifecycle.

Location: `app/commands/video_production/node/executors/`

**Implemented Executors:**
- `MergeVideos` - Concatenates videos via Lambda (FFmpeg)
- `GenerateVoiceover` - Text-to-speech via ElevenLabs API
- `GenerateTalkingHead` - Talking head videos via HeyGen API

**Executor Pattern:** Sidekiq jobs that (1) call ExecutionStarted to get process_uuid, (2) perform work (Lambda/API calls), (3) call ExecutionSucceeded with output, or ExecutionFailed on error.

**Future Executors:**
- `GenerateAnimation` - Veo 3 / Runway animations
- `RenderCode` - Remotion code screen animations
- `MixAudio` - FFmpeg audio replacement via Lambda
- `ComposeVideo` - FFmpeg picture-in-picture via Lambda

### Lambda Integration

Lambda functions are invoked **asynchronously** with callback-based completion following the llm-proxy pattern.

**Commands:**
- `VideoProduction::InvokeLambda` - Asynchronous Lambda invocation (`invocation_type: 'Event'`), returns `{ status: 'invoked' }` immediately
- `VideoProduction::InvokeLambdaLocal` - Local development alternative using `Process.spawn`, executes handler via Node.js in background process with 1-second delay, Lambda handler calls back to SPI endpoint
- `VideoProduction::ProcessExecutorCallback` - Processes callbacks from Lambda, calls ExecutionSucceeded or ExecutionFailed

**Async Flow:**
1. Executor invokes Lambda with `Event` type (returns 202 immediately)
2. Node stays in `in_progress` status (not completed)
3. Lambda executes asynchronously, processes video/audio
4. Lambda POSTs result to SPI callback endpoint (`/spi/video_production/executor_callback`)
5. `ProcessExecutorCallback` marks node as `completed` or `failed` with output

**Lambda Functions:** `video-merger` for FFmpeg video concatenation (Node.js 20, 3008 MB, 15 min timeout). Accepts `callback_url`, `node_uuid`, `executor_type` in payload. See `services/video_production/README.md` for deployment.

**SPI Callbacks:** Lambda callbacks use network-guarded SPI endpoints (no authentication required). Callback URL built from `Jiki.config.spi_base_url`. See `.context/spi.md` for SPI pattern details.

### External API Integration

External APIs use a **three-command pattern** (submit → poll → process) with inheritance from `CheckForResult` base class.

**Pattern:**
1. **Generate** command submits job to API, updates metadata with external job ID, queues CheckForResult polling
2. **CheckForResult** polls API status (60 max attempts, 10s interval), verifies process_uuid matches before processing, self-reschedules until complete/failed
3. **ProcessResult** downloads output, uploads to S3, marks execution succeeded

**Implemented:**
- **ElevenLabs** (`app/commands/video_production/apis/eleven_labs/`) - Text-to-speech via `POST /text-to-speech/{voice_id}`
- **HeyGen** (`app/commands/video_production/apis/heygen/`) - Talking head videos via `POST /v2/video/generate`, uses presigned URLs for audio/background inputs

**Future:** Veo 3 will follow same pattern.

### Node Metadata Fields

Common JSONB metadata fields: `process_uuid` (execution tracking), `started_at`/`completed_at` (timestamps), `audio_id`/`video_id`/`job_id` (external API tracking), `stage` (processing stage), `error` (failure message), `cost`, `retries`. See execution lifecycle commands for usage.

### Database Concurrency

**Process UUID Protection:**
All execution commands verify `process_uuid` matches before updating. Combined with `with_lock`, this ensures:
- Only the current execution can update the node
- Stale jobs (from webhooks or superseded executions) silently exit
- No data corruption from concurrent execution attempts

**Next.js/Rails Coordination:**
Column ownership prevents conflicts:
- **Next.js writes**: `type`, `inputs`, `config`, `asset`, `title`
- **Rails writes**: `status`, `metadata`, `output`, `is_valid`, `validation_errors`

Both systems can safely write to their columns simultaneously without conflicts.

## Usage Patterns

**Creating pipelines and nodes:** Use `VideoProduction::Pipeline::Create` and `VideoProduction::Node::Create` commands. See command files in `app/commands/video_production/`.

**Updating nodes:** `VideoProduction::Node::Update` automatically resets status to `pending` when structure fields (`inputs`, `config`, `asset`) change.

**Deleting nodes with references:** `VideoProduction::Node::Destroy` automatically cleans up references (removes UUID from array inputs, removes slot for single inputs).

## Local Development Setup

### Prerequisites

- **LocalStack**: AWS service emulation (S3, Lambda)
- **Docker**: For running LocalStack container
- **jq**: JSON processor for reading `.dockerimages.json`
- **Node.js**: For Lambda function dependencies
- **curl** and **zip**: For FFmpeg download and packaging

### Starting Development Environment

```bash
# Start all services (Rails, Sidekiq, LocalStack)
bin/dev
```

This command:
1. Starts LocalStack container on port 3065
2. Initializes S3 bucket from `Jiki.config.s3_bucket_video_production`
3. Starts Rails server and Sidekiq via hivemind

### Deploying Lambda to LocalStack

`bin/dev` automatically deploys missing Lambdas at startup. To manually deploy or redeploy:

```bash
# Deploy only missing Lambdas (skip if already deployed)
bin/deploy-lambdas --deploy-missing

# Force redeploy all Lambdas (use after modifying Lambda code)
bin/deploy-lambdas --deploy-all
```

**Note**: `--deploy-all` deletes and recreates all Lambdas, ensuring latest code is deployed. Use this after updating `services/video_production/video-merger/index.js` or other Lambda code.

The deployment process:
1. Installs Node.js dependencies for video-merger (`bin/setup-video-production`)
2. Downloads FFmpeg static binary (~50MB, one-time)
3. Creates deployment ZIP package
4. Deploys function to LocalStack as `jiki-video-merger-development`

### Quick Test: End-to-End Video Merge

**Run test:** `bin/test-video-merge` (requires FFmpeg, LocalStack running, Lambda deployed)

**What it tests:** Creates test videos, uploads to S3, creates pipeline with merge-videos node, executes merge via Lambda, verifies output. See script for details.

### LocalStack Configuration

**Endpoints** (from `jiki-config` gem):
- Development: `http://localhost:3065`
- Test: `http://localhost:3065`
- Production: Real AWS endpoints

**S3 Bucket** (from `../config/settings/local.yml`):
- Bucket name: `Jiki.config.s3_bucket_video_production` → `jiki-videos-dev`

**Lambda Function**:
- Function name: `jiki-video-merger-development`
- Runtime: Node.js 20.x
- Memory: 3008 MB
- Timeout: 15 minutes

**Network Configuration** (for Lambda callbacks):
LocalStack is configured with `LAMBDA_DOCKER_FLAGS=--add-host=local.jiki.io:host-gateway` to allow spawned Lambda containers to reach Rails server for SPI callbacks. See `.context/spi.md` for details.

### AWS Client Configuration

All AWS clients use the `Jiki.*_client` pattern from `jiki-config` gem:

```ruby
# S3 client (auto-configured for LocalStack in dev/test)
Jiki.s3_client.put_object(bucket: Jiki.config.s3_bucket_video_production, ...)

# Lambda client (auto-configured for LocalStack in dev/test)
Jiki.lambda_client.invoke(function_name: 'jiki-video-merger-development', ...)
```

**No environment variables needed** - configuration handled by `JikiConfig::GenerateAwsSettings`.

### Testing Video Merge Manually

**Quick approach:** Use `bin/test-video-merge` for automated end-to-end testing.

**Manual testing:**
1. Upload test videos to S3 (`Jiki.s3_client.put_object`)
2. Create pipeline and nodes (see `VideoProduction::Pipeline::Create`, `VideoProduction::Node::Create`)
3. Execute merge (`VideoProduction::Node::Executors::MergeVideos.perform_now(node)`)
4. Check output (node status and output fields)

### Troubleshooting

**LocalStack not starting:**
```bash
# Check if port 3065 is already in use
lsof -i :3065

# Restart LocalStack container
docker ps | grep localstack
docker restart <container-id>
```

**Lambda deployment fails:**
```bash
# Ensure LocalStack is running
curl http://localhost:3065/_localstack/health

# Force redeploy
bin/deploy-lambdas --deploy-all
```

**FFmpeg download fails:**
- Download manually from: https://johnvansickle.com/ffmpeg/builds/ffmpeg-git-amd64-static.tar.xz
- Extract and place `ffmpeg` binary in `services/video_production/video-merger/bin/`

### Directory Structure

```
services/video_production/
├── video-merger/              # Lambda function code
│   ├── index.js               # Lambda handler
│   ├── package.json           # Node.js dependencies
│   ├── bin/                   # FFmpeg binary (downloaded by setup script)
│   │   └── ffmpeg
│   └── node_modules/          # Installed by setup script
├── template.yaml              # AWS SAM deployment (production)
└── README.md                  # Lambda function documentation
```

### Local Lambda Execution (Fast Development)

**Pattern:** Use `INVOKE_LAMBDA_LOCALLY=true` to run Lambda handler directly via Node.js instead of deploying to LocalStack (~5s vs ~2min).

**Implementation:** `VideoProduction::InvokeLambdaLocal` (`app/commands/video_production/invoke_lambda_local.rb`):
- Spawns detached background process using `Process.spawn`
- Sleeps 1 second before executing (allows parent request to complete)
- Executes Lambda handler via Node.js with AWS env vars
- Lambda handler calls back to SPI endpoint via `fetch()`
- Returns `{ status: 'invoked' }` immediately (matching real Lambda async behavior)
- Logs output to `log/lambda_local.log`

**Usage:** `INVOKE_LAMBDA_LOCALLY=true bin/test-video-merge` or set `ENV['INVOKE_LAMBDA_LOCALLY'] = 'true'` in console.

**When to use:** Developing/debugging Lambda functions, rapid iteration. Don't use in production.

**Async Behavior:** Even in local mode, execution is asynchronous. Rails must be running to receive callbacks. Node transitions to `completed` via SPI callback, not directly from executor.

### Important Notes

- **LocalStack resets on restart** - Re-run `bin/deploy-lambdas --deploy-all` if you restart LocalStack
- **Lambda code changes** - Always run `bin/deploy-lambdas --deploy-all` after modifying Lambda handler code
- **S3 bucket auto-created** - `bin/init-localstack` creates bucket on every `bin/dev` run
- **No production impact** - All local dev uses LocalStack, production uses real AWS
- **Bucket name from config** - Never hardcode bucket names, always use `Jiki.config.s3_bucket_video_production`
- **Fast iteration** - Use `INVOKE_LAMBDA_LOCALLY=true` to skip Lambda deployment and run handler directly

## Key Architecture Points

1. **STI Prevention**: Models use `disable_sti!` to allow `type` column without Rails STI
2. **UUID Primary Keys**: Both tables use UUIDs for distributed systems support
3. **Validation**: Runs automatically on create/update, stores results in `is_valid`/`validation_errors` columns
4. **Status Management**: Automatically resets to `pending` when structure fields (`inputs`, `config`, `asset`) change
5. **Reference Cleanup**: Deleting node removes its UUID from other nodes' input arrays
6. **Shared Database**: Next.js (writes structure) and Rails (writes execution state/validation) have distinct column ownership
7. **Race Condition Protection**: process_uuid tracking + database locks prevent concurrent execution conflicts
8. **Admin Only**: All API endpoints require admin authentication
9. **LocalStack for Dev**: Use LocalStack for S3 and Lambda in development - see "Local Development Setup" above
10. **Config-driven**: All AWS configuration comes from `Jiki.config` and `Jiki.*_client` - never hardcode
11. **Fast iteration**: Use `INVOKE_LAMBDA_LOCALLY=true` to skip Lambda deployment and run handler directly via Node.js

## Related Files

- `VIDEO_PRODUCTION_PLAN.md` - Complete implementation roadmap
- `tmp-video-production/README.md` - TypeScript reference code from Next.js
- `.context/architecture.md` - Rails patterns and Mandate usage
- `.context/controllers.md` - Controller patterns
- `.context/testing.md` - Testing guidelines
- `bin/dev` - Starts LocalStack and initializes S3 buckets
- `bin/init-localstack` - S3 bucket initialization script
- `bin/deploy-lambdas` - Lambda deployment script (use `--deploy-missing` or `--deploy-all`)
- `bin/setup-video-production` - Lambda packaging and deployment (called by bin/deploy-lambdas)
