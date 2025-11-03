# Video Production Pipeline - Rails API Implementation Plan

## Progress

### Phase 1: Foundation ✅
- [x] Create migrations for `video_production_pipelines` and `video_production_nodes`
- [x] Create models with validations and associations
- [x] Set up FactoryBot factories
- [x] Write model tests (38 tests)
- [x] Run `bin/rails db:migrate`
- [x] Create `VideoProduction` module with `INPUT_SCHEMAS` constant
- [x] Create `VideoProduction::Node::ValidateInputs` command with tests (20 tests)

### Phase 2: API Endpoints ✅
#### Pipelines
- [x] Create controllers for pipelines (index with paginated results and show)
- [x] Create serializers
- [x] Add routes
- [x] Write controller tests and serializer tests

#### Nodes
- [x] Create controllers for nodes (pipeline/xxx/nodes and pipeline/xxx/node/yyy)
- [x] Create serializers
- [x] Add routes
- [x] Write controller tests and serializer tests

### Phase 3: Execute Command
- [ ] Create `VideoProduction::Node::Execute` command
- [ ] Write command tests
- [ ] Test job queueing

### Phase 4: MergeVideos Executor
- [ ] Create Lambda function for video merging
- [ ] Deploy Lambda with FFmpeg layer
- [ ] Create `VideoProduction::Executors::MergeVideos` command
- [ ] Set up AWS SDK and S3 integration
- [ ] Write executor tests (mock Lambda)
- [ ] Test end-to-end with real videos

### Phase 5: Remaining Executors
- [ ] TalkingHead executor + HeyGen integration
- [ ] GenerateVoiceover executor + ElevenLabs integration
- [ ] GenerateAnimation executor + Veo 3 integration
- [ ] RenderCode executor (Remotion)
- [ ] MixAudio executor (Lambda + FFmpeg)
- [ ] ComposeVideo executor (Lambda + FFmpeg)

### Phase 6: Next.js Integration
- [ ] Update Next.js Server Actions to call Rails API
- [ ] Replace local execution with API calls
- [ ] Update status polling to use API endpoint
- [ ] Configure CORS in Rails
- [ ] Test full flow from UI to execution

### Phase 7: Production Deployment
- [ ] Deploy Lambda functions to production
- [ ] Configure production environment variables
- [ ] Set up Sidekiq monitoring (Sidekiq Web UI)
- [ ] Configure error tracking (Sentry, etc.)
- [ ] Load testing and optimization
- [ ] Documentation updates

---

## Overview

This document outlines the implementation plan for integrating video production pipeline execution into the Jiki Rails API. The system will orchestrate video generation workflows using Sidekiq background jobs, Lambda functions for FFmpeg processing, and external APIs for AI-generated content.

## Reference Code

**Location:** `tmp-video-production/`

This directory contains reference implementations from the Next.js `code-videos` repository. The code is organized as follows:

```
tmp-video-production/
├── README.md                    # Complete reference guide
├── executors/                   # Node executors (merge-videos.ts)
├── ffmpeg/                      # FFmpeg utilities (merge.ts)
├── storage/                     # S3 operations (s3.ts, cache.ts)
├── db/                          # Database operations and migrations
├── types/                       # TypeScript type definitions
├── scripts/                     # CLI execution scripts
└── test-assets/                 # Test utilities
```

**Purpose:** These TypeScript files serve as **reference material** for translating Node.js patterns to Ruby/Rails equivalents. They show:
- How FFmpeg operations were structured
- S3 upload/download patterns
- JSONB partial update SQL patterns
- Database schema and operations
- Executor logic flow

**Important:** This is NOT production code. Use it as a reference while implementing Rails equivalents, then delete the directory after Phase 6 completion.

See `tmp-video-production/README.md` for detailed translation guides.

### Architecture

```
┌─────────────────────────────────────────────────┐
│          Next.js Visual Editor                  │
│     (code-videos repo - UI only)                │
│  • React Flow pipeline designer                 │
│  • Read-only database access                    │
│  • Calls Rails API for execution                │
└─────────────────┬───────────────────────────────┘
                  │
                  │ POST /v1/video_production/.../execute
                  │ GET  /v1/video_production/.../status
                  ↓
┌─────────────────────────────────────────────────┐
│           Rails API (this repo)                 │
│  • Orchestration & job queuing                  │
│  • Database writes (status, metadata, output)   │
│  • Sidekiq background jobs                      │
└─────────────────┬───────────────────────────────┘
                  │
         ┌────────┼────────┬────────┬──────────┐
         ↓        ↓        ↓        ↓          ↓
    ┌────────┐ ┌─────┐ ┌──────┐ ┌────────┐ ┌────┐
    │ Lambda │ │HeyGen│ │ Veo3 │ │Eleven  │ │ S3 │
    │(FFmpeg)│ │ API  │ │ API  │ │Labs API│ │    │
    └────────┘ └─────┘ └──────┘ └────────┘ └────┘
```

### Why Rails API?

- **Battle-tested background jobs**: Sidekiq is the gold standard for Ruby/Rails
- **Existing patterns**: Jobs, commands, serializers already established
- **Clean separation**: Next.js focuses on UI, Rails handles orchestration
- **Scalability**: Lambda for heavy lifting, Sidekiq for coordination
- **Monitoring**: Sidekiq Web UI, Rails logging, job retries built-in

---

## Database Schema

### Shared PostgreSQL Database

Both Next.js and Rails connect to the same PostgreSQL database. Column ownership prevents conflicts:

- **Next.js writes**: `type`, `inputs`, `config`, `asset`, `title`
- **Rails writes**: `status`, `metadata`, `output`

### Tables

#### video_production_pipelines

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_video_production_pipelines.rb
class CreateVideoProductionPipelines < ActiveRecord::Migration[8.0]
  def change
    create_table :video_production_pipelines, id: :string do |t|
      t.string :version, null: false, default: '1.0'
      t.string :title, null: false
      t.jsonb :config, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :video_production_pipelines, :updated_at
  end
end
```

**JSONB Columns:**
- `config`: `{ storage: { bucket, prefix }, workingDirectory }`
- `metadata`: `{ totalCost, estimatedTotalCost, progress: { completed, in_progress, pending, failed, total } }`

#### video_production_nodes

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_video_production_nodes.rb
class CreateVideoProductionNodes < ActiveRecord::Migration[8.0]
  def change
    create_table :video_production_nodes, id: false do |t|
      t.string :id, null: false
      t.string :pipeline_id, null: false
      t.string :title, null: false

      # Structure (Next.js writes)
      t.string :type, null: false
      t.jsonb :inputs, null: false, default: {}
      t.jsonb :config, null: false, default: {}
      t.jsonb :asset

      # Execution state (Rails writes)
      t.string :status, null: false, default: 'pending'
      t.jsonb :metadata
      t.jsonb :output
    end

    add_index :video_production_nodes, [:pipeline_id, :id], unique: true
    add_index :video_production_nodes, [:pipeline_id, :status]

    add_foreign_key :video_production_nodes, :video_production_pipelines,
                    column: :pipeline_id, on_delete: :cascade
  end
end
```

**Node Types:**
- `asset` - Static file references
- `talking-head` - HeyGen talking head videos
- `generate-animation` - Veo 3 / Runway animations
- `generate-voiceover` - ElevenLabs text-to-speech
- `render-code` - Remotion code screen animations
- `mix-audio` - FFmpeg audio replacement
- `merge-videos` - FFmpeg video concatenation
- `compose-video` - FFmpeg picture-in-picture overlays

**Status Values:** `pending`, `in_progress`, `completed`, `failed`

**JSONB Columns:**
- `inputs`: `{ "config": ["node_id"], "segments": ["node_id_1", "node_id_2"] }`
- `config`: Node-specific configuration (provider, API keys, settings)
- `asset`: For asset nodes: `{ source: "path", type: "text|json|video|audio" }`
- `metadata`: `{ startedAt, completedAt, jobId, cost, retries, error }`
- `output`: `{ type, s3Key, localFile, duration, size }`

---

## Models

### VideoProduction::Pipeline

```ruby
# app/models/video_production/pipeline.rb
class VideoProduction::Pipeline < ApplicationRecord
  self.table_name = 'video_production_pipelines'

  has_many :nodes, class_name: 'VideoProduction::Node',
           foreign_key: :pipeline_id, dependent: :destroy

  validates :title, presence: true
  validates :version, presence: true

  # JSONB accessors
  store_accessor :config, :storage, :working_directory
  store_accessor :metadata, :total_cost, :estimated_total_cost, :progress

  def total_cost
    metadata.dig('totalCost') || 0
  end

  def progress_summary
    metadata.dig('progress') || {
      'completed' => 0,
      'in_progress' => 0,
      'pending' => 0,
      'failed' => 0,
      'total' => 0
    }
  end
end
```

### VideoProduction::Node

```ruby
# app/models/video_production/node.rb
class VideoProduction::Node < ApplicationRecord
  self.table_name = 'video_production_nodes'
  self.primary_key = [:pipeline_id, :id]

  # Prevent Rails STI on 'type' column
  self.inheritance_column = :_type_disabled

  belongs_to :pipeline, class_name: 'VideoProduction::Pipeline',
             foreign_key: :pipeline_id

  validates :id, presence: true
  validates :pipeline_id, presence: true
  validates :title, presence: true
  validates :type, presence: true, inclusion: {
    in: %w[asset talking-head generate-animation generate-voiceover
           render-code mix-audio merge-videos compose-video]
  }
  validates :status, inclusion: { in: %w[pending in_progress completed failed] }

  # JSONB accessors
  store_accessor :config, :provider
  store_accessor :metadata, :started_at, :completed_at, :job_id, :cost, :retries, :error
  store_accessor :output, :s3_key, :local_file, :duration, :size

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }

  # Check if all input nodes are completed
  def inputs_satisfied?
    return true if inputs.blank?

    input_node_ids = inputs.values.flatten.compact
    return true if input_node_ids.empty?

    input_nodes = self.class.where(pipeline_id: pipeline_id, id: input_node_ids)
    input_nodes.all? { |node| node.status == 'completed' }
  end

  # Check if ready to execute
  def ready_to_execute?
    status == 'pending' && inputs_satisfied?
  end
end
```

**Important:** Use `self.inheritance_column = :_type_disabled` to prevent Rails STI behavior on the `type` column.

---

## API Controllers

### V1::VideoProduction::NodesController

```ruby
# app/controllers/v1/video_production/nodes_controller.rb
class V1::VideoProduction::NodesController < ApplicationController
  before_action :set_pipeline
  before_action :set_node, only: [:show, :execute, :status]

  # GET /v1/video_production/pipelines/:pipeline_id/nodes/:id
  def show
    render json: {
      node: SerializeVideoProduction::Node.(node)
    }
  end

  # POST /v1/video_production/pipelines/:pipeline_id/nodes/:id/execute
  def execute
    result = VideoProduction::Node::Execute.(node)

    if result[:success]
      render json: { status: 'queued', job_id: result[:job_id] }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  # GET /v1/video_production/pipelines/:pipeline_id/nodes/:id/status
  def status
    render json: {
      id: node.id,
      status: node.status,
      metadata: node.metadata || {},
      output: node.output || {}
    }
  end

  private

  def set_pipeline
    @pipeline = VideoProduction::Pipeline.find(params[:pipeline_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Pipeline not found' }, status: :not_found
  end

  def set_node
    @node = @pipeline.nodes.find_by!(id: params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Node not found' }, status: :not_found
  end

  attr_reader :pipeline, :node
end
```

### V1::VideoProduction::PipelinesController

```ruby
# app/controllers/v1/video_production/pipelines_controller.rb
class V1::VideoProduction::PipelinesController < ApplicationController
  # GET /v1/video_production/pipelines
  def index
    pipelines = VideoProduction::Pipeline.order(updated_at: :desc)

    render json: {
      pipelines: pipelines.map { |p| SerializeVideoProduction::Pipeline.(p) }
    }
  end

  # GET /v1/video_production/pipelines/:id
  def show
    pipeline = VideoProduction::Pipeline.includes(:nodes).find(params[:id])

    render json: {
      pipeline: SerializeVideoProduction::Pipeline.(pipeline, include_nodes: true)
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Pipeline not found' }, status: :not_found
  end
end
```

---

## Commands

### VideoProduction::Node::Execute

Entry point command that validates and queues appropriate executor.

```ruby
# app/commands/video_production/node/execute.rb
class VideoProduction::Node::Execute
  include Mandate

  initialize_with :node

  def call
    # Validate node is ready
    unless node.ready_to_execute?
      return {
        success: false,
        error: "Node not ready (status: #{node.status}, inputs satisfied: #{node.inputs_satisfied?})"
      }
    end

    # Dispatch to appropriate executor
    executor_class = executor_for_type(node.type)

    unless executor_class
      return {
        success: false,
        error: "No executor found for node type: #{node.type}"
      }
    end

    # Queue background job
    job = executor_class.defer(node.pipeline_id, node.id)

    {
      success: true,
      job_id: job.job_id
    }
  end

  private

  def executor_for_type(type)
    {
      'merge-videos' => VideoProduction::Executors::MergeVideos,
      'talking-head' => VideoProduction::Executors::TalkingHead,
      'generate-animation' => VideoProduction::Executors::GenerateAnimation,
      'generate-voiceover' => VideoProduction::Executors::GenerateVoiceover,
      'render-code' => VideoProduction::Executors::RenderCode,
      'mix-audio' => VideoProduction::Executors::MixAudio,
      'compose-video' => VideoProduction::Executors::ComposeVideo,
      'asset' => nil  # Asset nodes don't execute
    }[type]
  end
end
```

---

## Executors

Each executor is a Mandate command that runs as a Sidekiq job.

### VideoProduction::Executors::MergeVideos

FFmpeg video concatenation via Lambda.

```ruby
# app/commands/video_production/executors/merge_videos.rb
class VideoProduction::Executors::MergeVideos
  include Mandate

  queue_as :video_production

  initialize_with :pipeline_id, :node_id

  def call
    # 1. Mark as started
    update_node_status!('in_progress', started_at: Time.current)

    # 2. Validate inputs
    segment_ids = node.inputs['segments'] || []
    raise "No segments specified" if segment_ids.empty?
    raise "At least 2 segments required" if segment_ids.length < 2

    # 3. Get input nodes
    input_nodes = VideoProduction::Node.where(
      pipeline_id: pipeline_id,
      id: segment_ids
    ).index_by(&:id)

    # Preserve order from inputs array
    ordered_inputs = segment_ids.map { |id| input_nodes[id] }

    # 4. Download input videos from S3
    input_urls = ordered_inputs.map do |input_node|
      raise "Input node has no output" unless input_node.output&.dig('s3Key')
      "s3://#{Jiki.config.aws_s3_bucket}/#{input_node.output['s3Key']}"
    end

    # 5. Invoke Lambda to merge videos
    result = invoke_lambda_merge(input_urls)

    # 6. Update node with output
    update_node_completed!(
      s3_key: result[:s3_key],
      duration: result[:duration],
      size: result[:size],
      cost: result[:cost]
    )

  rescue StandardError => e
    update_node_failed!(e.message)
    raise
  end

  private

  def node
    @node ||= VideoProduction::Node.find_by!(
      pipeline_id: pipeline_id,
      id: node_id
    )
  end

  def invoke_lambda_merge(input_urls)
    lambda_client = Aws::Lambda::Client.new(region: Jiki.config.aws_region)

    payload = {
      input_videos: input_urls,
      output_bucket: Jiki.config.aws_s3_bucket,
      output_key: "pipelines/#{pipeline_id}/nodes/#{node_id}/output.mp4"
    }

    response = lambda_client.invoke(
      function_name: 'video-merger',
      invocation_type: 'RequestResponse',
      payload: JSON.generate(payload)
    )

    result = JSON.parse(response.payload.read, symbolize_names: true)

    raise "Lambda error: #{result[:error]}" if result[:error]

    result
  end

  def update_node_status!(status, **metadata_updates)
    # Use JSONB partial updates via raw SQL to avoid race conditions
    sql = "UPDATE video_production_nodes SET status = $1"
    params = [status]

    metadata_updates.each_with_index do |(key, value), idx|
      sql += ", metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{#{key}}', $#{idx + 2})"
      params << value.to_json
    end

    sql += " WHERE pipeline_id = $#{params.length + 1} AND id = $#{params.length + 2}"
    params += [pipeline_id, node_id]

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql, *params])
    )

    @node = nil  # Clear cache
  end

  def update_node_completed!(s3_key:, duration:, size:, cost:)
    sql = <<~SQL
      UPDATE video_production_nodes
      SET
        status = 'completed',
        metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{completedAt}', $1),
        metadata = jsonb_set(metadata, '{cost}', $2),
        output = jsonb_build_object(
          'type', 'video',
          's3Key', $3,
          'duration', $4,
          'size', $5
        )
      WHERE pipeline_id = $6 AND id = $7
    SQL

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([
        sql,
        Time.current.to_json,
        cost.to_json,
        s3_key,
        duration,
        size,
        pipeline_id,
        node_id
      ])
    )
  end

  def update_node_failed!(error_message)
    sql = <<~SQL
      UPDATE video_production_nodes
      SET
        status = 'failed',
        metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{completedAt}', $1),
        metadata = jsonb_set(metadata, '{error}', $2)
      WHERE pipeline_id = $3 AND id = $4
    SQL

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([
        sql,
        Time.current.to_json,
        error_message.to_json,
        pipeline_id,
        node_id
      ])
    )
  end
end
```

### VideoProduction::Executors::TalkingHead

HeyGen API integration for talking head videos.

```ruby
# app/commands/video_production/executors/talking_head.rb
class VideoProduction::Executors::TalkingHead
  include Mandate

  queue_as :video_production

  initialize_with :pipeline_id, :node_id

  def call
    update_node_status!('in_progress', started_at: Time.current)

    # Get script from input asset node
    script_node_id = node.inputs['script']&.first
    raise "No script input" unless script_node_id

    script_node = VideoProduction::Node.find_by!(
      pipeline_id: pipeline_id,
      id: script_node_id
    )

    script_text = download_script(script_node)

    # Call HeyGen API
    result = create_heygen_video(script_text)

    # Poll for completion (HeyGen is async)
    video_url = poll_heygen_completion(result[:video_id])

    # Download and upload to S3
    s3_key = download_and_upload(video_url)

    update_node_completed!(
      s3_key: s3_key,
      duration: result[:duration],
      size: result[:size],
      cost: result[:cost]
    )

  rescue StandardError => e
    update_node_failed!(e.message)
    raise
  end

  private

  def node
    @node ||= VideoProduction::Node.find_by!(
      pipeline_id: pipeline_id,
      id: node_id
    )
  end

  def create_heygen_video(script)
    # HeyGen API implementation
    # Returns: { video_id:, estimated_duration:, cost: }
  end

  def poll_heygen_completion(video_id, max_attempts: 60)
    # Poll HeyGen API every 10 seconds
    # Returns video URL when ready
    # Raises on timeout or error
  end

  # Reuse update methods from MergeVideos
  # (Extract to concern or base class)
end
```

### Other Executors

Follow the same pattern for:

- **VideoProduction::Executors::GenerateAnimation** - Veo 3 / Runway API
- **VideoProduction::Executors::GenerateVoiceover** - ElevenLabs API
- **VideoProduction::Executors::RenderCode** - Remotion (local or Lambda)
- **VideoProduction::Executors::MixAudio** - FFmpeg via Lambda
- **VideoProduction::Executors::ComposeVideo** - FFmpeg via Lambda

---

## JSONB Partial Update Strategy

**CRITICAL:** All database updates MUST use `jsonb_set()` to avoid race conditions.

### Why Partial Updates?

- **Concurrency**: Next.js updates structure (`config`), Rails updates state (`metadata`)
- **Safety**: Prevents data loss when both processes update same row
- **Performance**: Smaller updates, less WAL overhead

### Rails Pattern

```ruby
# ❌ WRONG: Replaces entire JSONB column
node.metadata = { startedAt: Time.current }
node.save!

# ✅ CORRECT: Partial update via SQL
sql = <<~SQL
  UPDATE video_production_nodes
  SET metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{startedAt}', $1)
  WHERE pipeline_id = $2 AND id = $3
SQL

ActiveRecord::Base.connection.execute(
  ActiveRecord::Base.sanitize_sql([sql, Time.current.to_json, pipeline_id, node_id])
)
```

### Multiple Keys

```ruby
sql = <<~SQL
  UPDATE video_production_nodes
  SET
    metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{startedAt}', $1),
    metadata = jsonb_set(metadata, '{jobId}', $2)
  WHERE pipeline_id = $3 AND id = $4
SQL

ActiveRecord::Base.connection.execute(
  ActiveRecord::Base.sanitize_sql([
    sql,
    Time.current.to_json,
    job_id.to_json,
    pipeline_id,
    node_id
  ])
)
```

### Nested Keys

```ruby
# Update metadata.progress.completed
sql = <<~SQL
  UPDATE video_production_pipelines
  SET metadata = jsonb_set(metadata, '{progress,completed}', $1)
  WHERE id = $2
SQL
```

### Helper Method (Optional)

```ruby
# lib/jsonb_updater.rb
module JsonbUpdater
  def self.update_node_metadata(pipeline_id, node_id, **updates)
    sql = "UPDATE video_production_nodes SET "

    set_clauses = updates.map.with_index do |(key, value), idx|
      if idx == 0
        "metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{#{key}}', $#{idx + 1})"
      else
        "metadata = jsonb_set(metadata, '{#{key}}', $#{idx + 1})"
      end
    end

    sql += set_clauses.join(", ")
    sql += " WHERE pipeline_id = $#{updates.length + 1} AND id = $#{updates.length + 2}"

    params = updates.values.map(&:to_json) + [pipeline_id, node_id]

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql, *params])
    )
  end
end

# Usage
JsonbUpdater.update_node_metadata(
  pipeline_id,
  node_id,
  startedAt: Time.current,
  jobId: job.job_id,
  retries: 0
)
```

---

## Serializers

### SerializeVideoProduction::Pipeline

```ruby
# app/serializers/serialize_video_production/pipeline.rb
class SerializeVideoProduction::Pipeline
  include Mandate

  initialize_with :pipeline, :include_nodes

  def initialize(pipeline, include_nodes: false)
    @pipeline = pipeline
    @include_nodes = include_nodes
  end

  def call
    {
      id: pipeline.id,
      version: pipeline.version,
      title: pipeline.title,
      created_at: pipeline.created_at,
      updated_at: pipeline.updated_at,
      config: pipeline.config,
      metadata: pipeline.metadata
    }.tap do |hash|
      if include_nodes
        hash[:nodes] = pipeline.nodes.map { |n| SerializeVideoProduction::Node.(n) }
      end
    end
  end

  private
  attr_reader :pipeline, :include_nodes
end
```

### SerializeVideoProduction::Node

```ruby
# app/serializers/serialize_video_production/node.rb
class SerializeVideoProduction::Node
  include Mandate

  initialize_with :node

  def call
    {
      id: node.id,
      pipeline_id: node.pipeline_id,
      title: node.title,
      type: node.type,
      inputs: node.inputs,
      config: node.config,
      asset: node.asset,
      status: node.status,
      metadata: node.metadata,
      output: node.output
    }
  end
end
```

---

## Background Jobs Configuration

### Sidekiq Queue

Add new queue in `config/sidekiq.yml`:

```yaml
:queues:
  - critical
  - default
  - video_production  # New queue for video processing
  - mailers
  - background
  - low
```

Priority: Between `default` and `mailers` (video processing is important but not critical).

### Job Defaults

Executors inherit from ApplicationJob with sensible defaults:

```ruby
class ApplicationJob < ActiveJob::Base
  retry_on ActiveRecord::Deadlocked
  discard_on ActiveJob::DeserializationError

  # Video production jobs may take a while
  # Let Sidekiq handle retries
end
```

### Rate Limiting for External APIs

Use `requeue_job!` for rate limits:

```ruby
class VideoProduction::Executors::TalkingHead
  def call
    result = heygen_api_call
  rescue HeyGenRateLimitError => e
    retry_after = e.retry_after || 60
    requeue_job!(retry_after)
  end
end
```

---

## Lambda Integration

### Lambda Functions Needed

#### 1. video-merger

FFmpeg concatenation of video segments.

```javascript
// lambda/video-merger/index.js
const { spawnSync } = require('child_process');
const { S3 } = require('@aws-sdk/client-s3');
const { Upload } = require('@aws-sdk/lib-storage');
const fs = require('fs');

exports.handler = async (event) => {
  const { input_videos, output_bucket, output_key } = event;

  // Download videos to /tmp
  const inputFiles = [];
  for (let i = 0; i < input_videos.length; i++) {
    const localPath = `/tmp/input_${i}.mp4`;
    await downloadFromS3(input_videos[i], localPath);
    inputFiles.push(localPath);
  }

  // Create concat file
  const concatFile = '/tmp/concat.txt';
  fs.writeFileSync(
    concatFile,
    inputFiles.map(f => `file '${f}'`).join('\n')
  );

  // Run FFmpeg
  const outputPath = '/tmp/output.mp4';
  const result = spawnSync('ffmpeg', [
    '-f', 'concat',
    '-safe', '0',
    '-i', concatFile,
    '-c', 'copy',
    outputPath
  ]);

  if (result.status !== 0) {
    throw new Error(`FFmpeg failed: ${result.stderr.toString()}`);
  }

  // Get video metadata
  const stats = fs.statSync(outputPath);
  const duration = getVideoDuration(outputPath);

  // Upload to S3
  await uploadToS3(outputPath, output_bucket, output_key);

  return {
    s3_key: output_key,
    duration: duration,
    size: stats.size,
    cost: calculateCost(duration, stats.size)
  };
};
```

**Lambda Configuration:**
- Runtime: Node.js 20
- Memory: 3008 MB (for large videos)
- Timeout: 15 minutes
- Ephemeral storage: 10 GB
- Layer: FFmpeg static binary (https://github.com/serverlesspub/ffmpeg-aws-lambda-layer)

#### 2. audio-mixer

FFmpeg audio track replacement.

#### 3. video-composer

FFmpeg picture-in-picture compositing.

### AWS SDK Setup

```ruby
# Gemfile
gem 'aws-sdk-lambda'
gem 'aws-sdk-s3'

# config/initializers/aws.rb
Aws.config.update(
  region: Jiki.config.aws_region,
  credentials: Aws::Credentials.new(
    Jiki.config.aws_access_key_id,
    Jiki.config.aws_secret_access_key
  )
)
```

### Lambda Invocation Helper

```ruby
# lib/lambda_invoker.rb
class LambdaInvoker
  def self.invoke(function_name, payload)
    client = Aws::Lambda::Client.new

    response = client.invoke(
      function_name: function_name,
      invocation_type: 'RequestResponse',
      payload: JSON.generate(payload)
    )

    result = JSON.parse(response.payload.read, symbolize_names: true)

    if response.status_code != 200
      raise "Lambda invocation failed: #{response.function_error}"
    end

    if result[:errorMessage]
      raise "Lambda error: #{result[:errorMessage]}"
    end

    result
  end
end

# Usage
result = LambdaInvoker.invoke('video-merger', {
  input_videos: ['s3://bucket/video1.mp4', 's3://bucket/video2.mp4'],
  output_bucket: 'jiki-videos',
  output_key: 'output/merged.mp4'
})
```

---

## External API Integrations

### HeyGen API

```ruby
# lib/heygen_client.rb
class HeygenClient
  BASE_URL = 'https://api.heygen.com/v1'

  def initialize(api_key = Jiki.config.heygen_api_key)
    @api_key = api_key
  end

  def create_video(avatar_id:, script:, voice_id:)
    response = connection.post('video/generate') do |req|
      req.body = {
        avatar_id: avatar_id,
        voice_id: voice_id,
        input_text: script
      }
    end

    handle_response(response)
  end

  def get_video_status(video_id)
    response = connection.get("video/status/#{video_id}")
    handle_response(response)
  end

  private

  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.response :json
      f.headers['X-Api-Key'] = @api_key
      f.adapter Faraday.default_adapter
    end
  end

  def handle_response(response)
    case response.status
    when 200..299
      response.body
    when 429
      raise HeyGenRateLimitError.new(response.headers['Retry-After'])
    else
      raise HeyGenAPIError.new("API error: #{response.status}")
    end
  end
end

class HeyGenRateLimitError < StandardError
  attr_reader :retry_after

  def initialize(retry_after)
    @retry_after = retry_after.to_i
    super("Rate limited, retry after #{retry_after} seconds")
  end
end
```

### ElevenLabs API

```ruby
# lib/elevenlabs_client.rb
class ElevenlabsClient
  BASE_URL = 'https://api.elevenlabs.io/v1'

  def text_to_speech(text:, voice_id:)
    response = connection.post("text-to-speech/#{voice_id}") do |req|
      req.body = { text: text }
    end

    # Returns binary audio data
    response.body
  end

  # Similar pattern to HeyGen
end
```

---

## Testing Strategy

### Model Tests

```ruby
# test/models/video_production/node_test.rb
require "test_helper"

class VideoProduction::NodeTest < ActiveSupport::TestCase
  test "validates presence of required fields" do
    node = VideoProduction::Node.new
    assert_not node.valid?
    assert_includes node.errors[:id], "can't be blank"
  end

  test "inputs_satisfied? returns true when no inputs" do
    node = create(:video_production_node, inputs: {})
    assert node.inputs_satisfied?
  end

  test "inputs_satisfied? returns true when all inputs completed" do
    pipeline = create(:video_production_pipeline)
    input1 = create(:video_production_node, pipeline: pipeline, status: 'completed')
    input2 = create(:video_production_node, pipeline: pipeline, status: 'completed')

    node = create(:video_production_node,
      pipeline: pipeline,
      inputs: { 'segments' => [input1.id, input2.id] }
    )

    assert node.inputs_satisfied?
  end

  test "inputs_satisfied? returns false when any input pending" do
    pipeline = create(:video_production_pipeline)
    input1 = create(:video_production_node, pipeline: pipeline, status: 'completed')
    input2 = create(:video_production_node, pipeline: pipeline, status: 'pending')

    node = create(:video_production_node,
      pipeline: pipeline,
      inputs: { 'segments' => [input1.id, input2.id] }
    )

    assert_not node.inputs_satisfied?
  end
end
```

### Controller Tests

```ruby
# test/controllers/v1/video_production/nodes_controller_test.rb
require "test_helper"

class V1::VideoProduction::NodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in @user

    @pipeline = create(:video_production_pipeline)
    @node = create(:video_production_node, pipeline: @pipeline)
  end

  test "execute queues job when node is ready" do
    @node.update!(status: 'pending')

    assert_enqueued_with(job: MandateJob) do
      post execute_v1_video_production_pipeline_node_path(
        @pipeline.id,
        @node.id
      )
    end

    assert_response :success
    assert_match(/queued/, response.body)
  end

  test "execute returns error when node not ready" do
    @node.update!(status: 'in_progress')

    post execute_v1_video_production_pipeline_node_path(
      @pipeline.id,
      @node.id
    )

    assert_response :unprocessable_entity
  end

  test "status returns current node state" do
    @node.update!(
      status: 'in_progress',
      metadata: { 'startedAt' => Time.current.iso8601 }
    )

    get status_v1_video_production_pipeline_node_path(
      @pipeline.id,
      @node.id
    )

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 'in_progress', json['status']
    assert json['metadata']['startedAt'].present?
  end
end
```

### Command Tests

```ruby
# test/commands/video_production/node/execute_test.rb
require "test_helper"

class VideoProduction::Node::ExecuteTest < ActiveSupport::TestCase
  test "queues executor job for ready node" do
    node = create(:video_production_node,
      type: 'merge-videos',
      status: 'pending'
    )

    assert_enqueued_with(
      job: MandateJob,
      args: ['VideoProduction::Executors::MergeVideos', node.pipeline_id, node.id]
    ) do
      result = VideoProduction::Node::Execute.(node)
      assert result[:success]
    end
  end

  test "returns error when node not ready" do
    node = create(:video_production_node, status: 'completed')

    result = VideoProduction::Node::Execute.(node)

    assert_not result[:success]
    assert_match(/not ready/, result[:error])
  end
end
```

### Executor Tests

```ruby
# test/commands/video_production/executors/merge_videos_test.rb
require "test_helper"

class VideoProduction::Executors::MergeVideosTest < ActiveSupport::TestCase
  test "merges videos and updates node" do
    pipeline = create(:video_production_pipeline)

    # Create input nodes with outputs
    input1 = create(:video_production_node,
      pipeline: pipeline,
      status: 'completed',
      output: { 's3Key' => 'input1.mp4' }
    )
    input2 = create(:video_production_node,
      pipeline: pipeline,
      status: 'completed',
      output: { 's3Key' => 'input2.mp4' }
    )

    # Create merge node
    merge_node = create(:video_production_node,
      pipeline: pipeline,
      type: 'merge-videos',
      inputs: { 'segments' => [input1.id, input2.id] },
      status: 'pending'
    )

    # Mock Lambda invocation
    LambdaInvoker.stub :invoke, lambda_success_response do
      perform_enqueued_jobs do
        VideoProduction::Executors::MergeVideos.defer(
          pipeline.id,
          merge_node.id
        )
      end
    end

    # Verify node updated
    merge_node.reload
    assert_equal 'completed', merge_node.status
    assert merge_node.output['s3Key'].present?
  end

  private

  def lambda_success_response
    {
      s3_key: 'output/merged.mp4',
      duration: 120.5,
      size: 10_485_760,
      cost: 0.05
    }
  end
end
```

---

## FactoryBot Factories

```ruby
# test/factories/video_production/pipelines.rb
FactoryBot.define do
  factory :video_production_pipeline, class: 'VideoProduction::Pipeline' do
    id { SecureRandom.uuid }
    title { "Test Pipeline" }
    version { "1.0" }
    config do
      {
        'storage' => {
          'bucket' => 'jiki-videos-test',
          'prefix' => "pipelines/#{id}/"
        },
        'workingDirectory' => './output'
      }
    end
    metadata do
      {
        'totalCost' => 0,
        'estimatedTotalCost' => 0,
        'progress' => {
          'completed' => 0,
          'in_progress' => 0,
          'pending' => 0,
          'failed' => 0,
          'total' => 0
        }
      }
    end
  end
end

# test/factories/video_production/nodes.rb
FactoryBot.define do
  factory :video_production_node, class: 'VideoProduction::Node' do
    association :pipeline, factory: :video_production_pipeline

    id { SecureRandom.uuid }
    title { "Test Node" }
    type { 'asset' }
    inputs { {} }
    config { {} }
    status { 'pending' }

    trait :merge_videos do
      type { 'merge-videos' }
      config { { 'provider' => 'ffmpeg' } }
    end

    trait :talking_head do
      type { 'talking-head' }
      config do
        {
          'provider' => 'heygen',
          'avatarId' => 'avatar-1',
          'voiceId' => 'voice-1'
        }
      end
    end

    trait :completed do
      status { 'completed' }
      metadata do
        {
          'startedAt' => 1.hour.ago.iso8601,
          'completedAt' => Time.current.iso8601,
          'cost' => 0.05
        }
      end
      output do
        {
          'type' => 'video',
          's3Key' => 'output/test.mp4',
          'duration' => 60.0,
          'size' => 5_242_880
        }
      end
    end
  end
end
```

---

## Configuration

### Jiki Config Gem

Add video production settings to the config gem:

```ruby
# In ../config/lib/jiki/config.rb (or equivalent)

module Jiki
  class Config
    # Existing config...

    # Video Production
    setting :aws_region, default: 'us-east-1'
    setting :aws_access_key_id
    setting :aws_secret_access_key
    setting :aws_s3_bucket

    # External APIs
    setting :heygen_api_key
    setting :veo3_api_key
    setting :elevenlabs_api_key
    setting :runway_api_key
  end
end
```

### Environment Variables

```bash
# .env.development
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
AWS_S3_BUCKET=jiki-videos-dev

HEYGEN_API_KEY=your_heygen_key
ELEVENLABS_API_KEY=your_elevenlabs_key
```

---

## Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :v1 do
    namespace :video_production do
      resources :pipelines, only: [:index, :show] do
        resources :nodes, only: [:show] do
          member do
            post :execute
            get :status
          end
        end
      end
    end
  end
end
```

**Routes:**
- `GET    /v1/video_production/pipelines`
- `GET    /v1/video_production/pipelines/:id`
- `GET    /v1/video_production/pipelines/:pipeline_id/nodes/:id`
- `POST   /v1/video_production/pipelines/:pipeline_id/nodes/:id/execute`
- `GET    /v1/video_production/pipelines/:pipeline_id/nodes/:id/status`

---

## Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Create migrations for `video_production_pipelines` and `video_production_nodes`
- [ ] Create models with validations and associations
- [ ] Set up FactoryBot factories
- [ ] Write model tests
- [ ] Run `bin/rails db:migrate`

### Phase 2: API Endpoints (Week 1-2)
- [ ] Create controllers for pipelines and nodes
- [ ] Create serializers
- [ ] Add routes
- [ ] Write controller tests
- [ ] Test with Postman/curl

### Phase 3: Execute Command (Week 2)
- [ ] Create `VideoProduction::Node::Execute` command
- [ ] Write command tests
- [ ] Test job queueing

### Phase 4: MergeVideos Executor (Week 2-3)
- [ ] Create Lambda function for video merging
- [ ] Deploy Lambda with FFmpeg layer
- [ ] Create `VideoProduction::Executors::MergeVideos` command
- [ ] Set up AWS SDK and S3 integration
- [ ] Write executor tests (mock Lambda)
- [ ] Test end-to-end with real videos

### Phase 5: Remaining Executors (Week 3-4)
- [ ] TalkingHead executor + HeyGen integration
- [ ] GenerateVoiceover executor + ElevenLabs integration
- [ ] GenerateAnimation executor + Veo 3 integration
- [ ] RenderCode executor (Remotion)
- [ ] MixAudio executor (Lambda + FFmpeg)
- [ ] ComposeVideo executor (Lambda + FFmpeg)

### Phase 6: Next.js Integration (Week 4)
- [ ] Update Next.js Server Actions to call Rails API
- [ ] Replace local execution with API calls
- [ ] Update status polling to use API endpoint
- [ ] Configure CORS in Rails
- [ ] Test full flow from UI to execution

### Phase 7: Production Deployment (Week 5)
- [ ] Deploy Lambda functions to production
- [ ] Configure production environment variables
- [ ] Set up Sidekiq monitoring (Sidekiq Web UI)
- [ ] Configure error tracking (Sentry, etc.)
- [ ] Load testing and optimization
- [ ] Documentation updates

---

## Monitoring & Debugging

### Sidekiq Web UI

Mount Sidekiq Web in routes (admin only):

```ruby
# config/routes.rb
require 'sidekiq/web'

Rails.application.routes.draw do
  # Authenticate admin users
  authenticate :user, ->(user) { user.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end
end
```

Access at: `http://localhost:3060/sidekiq`

### Logging

```ruby
# config/environments/production.rb
config.log_level = :info
config.log_tags = [:request_id]

# Log job execution
Rails.logger.info("[VideoProduction] Executing #{node.type} node #{node.id}")
```

### Error Tracking

```ruby
# config/initializers/sentry.rb (if using Sentry)
Sentry.init do |config|
  config.dsn = Jiki.config.sentry_dsn
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
end
```

### Lambda Logs

Access via CloudWatch:
- `/aws/lambda/video-merger`
- `/aws/lambda/audio-mixer`
- `/aws/lambda/video-composer`

---

## Before Committing

- [ ] Run `bin/rails test` - All tests pass
- [ ] Run `bin/rubocop` - No linting errors
- [ ] Run `bin/brakeman` - No security issues
- [ ] Update `.context/` files if patterns changed
- [ ] Update `README.md` with new API endpoints
- [ ] Create pull request with comprehensive description

---

## Related Documentation

- **Background Jobs**: `.context/jobs.md` - Sidekiq patterns with Mandate
- **Commands**: `.context/architecture.md` - Mandate command pattern
- **Testing**: `.context/testing.md` - FactoryBot and test organization
- **Configuration**: `.context/configuration.md` - Jiki Config Gem
- **API**: `.context/api.md` - API endpoint conventions
- **Controllers**: `.context/controllers.md` - Controller patterns

---

## Cost Estimate (50 Videos)

- **Lambda (FFmpeg)**: ~$2/month (pay per execution)
- **S3 Storage**: ~$5/month (videos + intermediate files)
- **HeyGen API**: $20-50 per video (~$1000-2500 total)
- **ElevenLabs API**: ~$10 per hour of audio (~$500 total)
- **Veo 3 API**: TBD (pricing not public yet)

**Total for 50 videos**: ~$2000-3500 one-time + $7/month ongoing

---

**Next Steps:**
1. Review this plan with team
2. Set up AWS account and Lambda functions
3. Start with Phase 1 (database + models)
4. Iterate through phases with testing at each step
